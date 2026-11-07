package com.tecsys.domain.decision.terrain;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Relevo COP30 da OpenTopography com cache em disco.
 *
 * <p>O servidor corta downloads grandes, então a caixa é baixada em blocos de 0,25°, cada bloco é
 * validado antes de entrar no cache e os blocos são montados num mosaico. O cache usa o mesmo
 * formato do motor de referência em Python ({@code indice.json} + {@code dem_<hash>.tif}), então os
 * arquivos de um servem no outro. A API grátis permite 50 chamadas por dia: cada área só é baixada
 * uma vez.
 *
 * <p>Se o relevo não puder ser obtido, o cálculo <b>falha</b>. O motor antigo caía em terreno plano
 * sem avisar e declarava ~99,9% de cobertura quando a real ficava entre 43% e 69%.
 */
@Service
public class DemService {

    private static final Logger log = LoggerFactory.getLogger(DemService.class);
    private static final double BLOCK_DEGREES = 0.25;
    private static final String INDEX_FILE = "indice.json";

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final Path cacheDir;
    private final String globalDemUrl;
    private final String apiKey;
    private final String dataset;
    private final int downloadAttempts;

    public DemService(
            ObjectMapper objectMapper,
            @Value("${app.terrain.cache-dir:cache/dem}") String cacheDir,
            @Value("${app.terrain.opentopography.globaldem-url:https://portal.opentopography.org/API/globaldem}") String globalDemUrl,
            @Value("${app.terrain.opentopography.api-key:}") String apiKey,
            @Value("${app.terrain.opentopography.dataset:COP30}") String dataset,
            @Value("${app.terrain.download-attempts:4}") int downloadAttempts
    ) {
        this.objectMapper = objectMapper;
        this.cacheDir = Path.of(cacheDir);
        this.globalDemUrl = globalDemUrl;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.dataset = dataset;
        this.downloadAttempts = Math.max(1, downloadAttempts);
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(20))
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
    }

    public record TerrainInfo(double[] box, int blocks, boolean fromCache, double downloadSeconds) {
    }

    public record Loaded(Terrain terrain, TerrainInfo info) {
    }

    /** Relevo que cobre a caixa (graus). Sincronizado: o índice do cache é um arquivo só. */
    public synchronized Loaded load(double south, double north, double west, double east) throws IOException {
        south = Math.floor(south * 100) / 100;
        west = Math.floor(west * 100) / 100;
        north = Math.ceil(north * 100) / 100;
        east = Math.ceil(east * 100) / 100;

        Map<String, double[]> index = readIndex();
        Path whole = findContaining(index, south, north, west, east);
        if (whole != null) {
            return new Loaded(GeoTiffReader.read(whole), new TerrainInfo(new double[]{south, north, west, east}, 1, true, 0));
        }

        long t0 = System.nanoTime();
        boolean allCached = true;
        List<GridTerrain> blocks = new ArrayList<>();
        for (double la = Math.floor(south / BLOCK_DEGREES) * BLOCK_DEGREES; la < north; la += BLOCK_DEGREES) {
            for (double lo = Math.floor(west / BLOCK_DEGREES) * BLOCK_DEGREES; lo < east; lo += BLOCK_DEGREES) {
                double s = round4(la);
                double w = round4(lo);
                Path cached = findContaining(index, s, round4(s + BLOCK_DEGREES), w, round4(w + BLOCK_DEGREES));
                if (cached == null) {
                    allCached = false;
                    cached = download(index, s, round4(s + BLOCK_DEGREES), w, round4(w + BLOCK_DEGREES));
                }
                blocks.add(GeoTiffReader.read(cached));
            }
        }
        double seconds = (System.nanoTime() - t0) / 1e9;
        Terrain terrain = blocks.size() == 1 ? blocks.get(0) : mosaic(blocks);
        return new Loaded(terrain, new TerrainInfo(new double[]{south, north, west, east}, blocks.size(), allCached, seconds));
    }

    static GridTerrain mosaic(List<GridTerrain> blocks) {
        double dx = blocks.get(0).dx();
        double dy = blocks.get(0).dy();
        double lon0 = Double.POSITIVE_INFINITY;
        double lat0 = Double.NEGATIVE_INFINITY;
        double lonEnd = Double.NEGATIVE_INFINITY;
        double latEnd = Double.POSITIVE_INFINITY;
        for (GridTerrain b : blocks) {
            lon0 = Math.min(lon0, b.lon0());
            lat0 = Math.max(lat0, b.lat0());
            lonEnd = Math.max(lonEnd, b.lon0() + (b.width() - 1) * dx);
            latEnd = Math.min(latEnd, b.lat0() - (b.height() - 1) * dy);
        }
        int w = (int) Math.round((lonEnd - lon0) / dx) + 1;
        int h = (int) Math.round((lat0 - latEnd) / dy) + 1;
        float[] z = new float[h * w];
        for (GridTerrain b : blocks) {
            int i0 = (int) Math.round((lat0 - b.lat0()) / dy);
            int j0 = (int) Math.round((b.lon0() - lon0) / dx);
            float[] src = b.data();
            int bw = b.width();
            for (int i = 0; i < b.height() && i0 + i < h; i++) {
                int len = Math.min(bw, w - j0);
                System.arraycopy(src, i * bw, z, (i0 + i) * w + j0, len);
            }
        }
        return new GridTerrain(z, h, w, lon0, lat0, dx, dy, "COP30:mosaico " + blocks.size() + " blocos");
    }

    private Path download(Map<String, double[]> index, double s, double n, double w, double e) throws IOException {
        if (apiKey.isEmpty()) {
            throw new IOException("OPENTOPOGRAPHY_API_KEY não definida: sem ela o motor não obtém o relevo. "
                    + "Coloque a chave em MOTOR/.env.properties ou desligue o relevo de propósito com MOTOR_USE_TERRAIN=false.");
        }
        Files.createDirectories(cacheDir);
        String name = "dem_" + sha1(String.format(Locale.US, "%s:%.2f:%.2f:%.2f:%.2f", dataset, s, n, w, e)).substring(0, 16) + ".tif";
        Path target = cacheDir.resolve(name);
        if (!Files.exists(target)) {
            String url = globalDemUrl
                    + "?demtype=" + enc(dataset)
                    + String.format(Locale.US, "&south=%.5f&north=%.5f&west=%.5f&east=%.5f", s, n, w, e)
                    + "&outputFormat=GTiff&API_Key=" + enc(apiKey);
            log.info("Baixando relevo {} [S:{} N:{} W:{} E:{}]", dataset, s, n, w, e);
            Exception last = null;
            for (int attempt = 0; attempt < downloadAttempts; attempt++) {
                try {
                    fetchTo(url, target);
                    last = null;
                    break;
                } catch (Exception ex) {
                    last = ex;
                    log.warn("Falha ao baixar relevo (tentativa {}/{}): {}", attempt + 1, downloadAttempts, ex.getMessage());
                    if (ex instanceof InterruptedException) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                    sleepQuietly(5_000L * (attempt + 1));
                }
            }
            if (last != null) {
                throw new IOException("Não foi possível baixar o relevo da OpenTopography: " + last.getMessage(), last);
            }
        }
        index.put(name, new double[]{s, n, w, e});
        writeIndex(index);
        return target;
    }

    private void fetchTo(String url, Path target) throws IOException, InterruptedException {
        HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(300))
                .header("Accept", "image/tiff, application/octet-stream")
                .GET().build();
        HttpResponse<byte[]> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofByteArray());
        byte[] body = resp.body();
        boolean tiff = body.length > 4
                && ((body[0] == 'I' && body[1] == 'I' && body[2] == 42 && body[3] == 0)
                || (body[0] == 'M' && body[1] == 'M' && body[2] == 0 && body[3] == 42));
        if (resp.statusCode() != 200 || !tiff) {
            String msg = new String(body, 0, Math.min(body.length, 200), StandardCharsets.UTF_8);
            throw new IOException("HTTP " + resp.statusCode() + ": " + msg);
        }
        Path part = target.resolveSibling(target.getFileName() + ".part");
        Files.write(part, body);
        try {
            GeoTiffReader.read(part); // download truncado gera bloco corrompido
        } catch (IOException ex) {
            Files.deleteIfExists(part);
            throw ex;
        }
        Files.move(part, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    }

    private Path findContaining(Map<String, double[]> index, double s, double n, double w, double e) {
        for (Map.Entry<String, double[]> it : index.entrySet()) {
            double[] b = it.getValue();
            Path f = cacheDir.resolve(it.getKey());
            if (b.length >= 4 && b[0] <= s && b[1] >= n && b[2] <= w && b[3] >= e && Files.exists(f)) {
                return f;
            }
        }
        return null;
    }

    private Map<String, double[]> readIndex() throws IOException {
        Path f = cacheDir.resolve(INDEX_FILE);
        if (!Files.exists(f)) return new LinkedHashMap<>();
        return objectMapper.readValue(f.toFile(), new TypeReference<LinkedHashMap<String, double[]>>() { });
    }

    private void writeIndex(Map<String, double[]> index) throws IOException {
        Path f = cacheDir.resolve(INDEX_FILE);
        Path tmp = cacheDir.resolve(INDEX_FILE + ".tmp");
        objectMapper.writeValue(tmp.toFile(), index);
        Files.move(tmp, f, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    }

    private static double round4(double v) {
        return Math.round(v * 10_000.0) / 10_000.0;
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }

    private static String sha1(String s) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-1").digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static void sleepQuietly(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
