package com.tecsys.domain.decision.terrain;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Relevo Copernicus DEM GLO-30 do AWS Open Data, com cache em disco e mirror local opcional.
 *
 * <p>Os tiles são quadrados de 1°, baixados sem chave de API. A ordem de busca é cache, mirror e
 * S3. Um tile obtido do mirror é copiado para o cache antes da leitura. Se o relevo não puder ser
 * obtido, o cálculo falha; nunca há queda silenciosa para terreno plano.
 */
@Service
public class DemService {

    private static final Logger log = LoggerFactory.getLogger(DemService.class);
    private static final String CACHE_SUBDIR = "aws-copernicus";
    private static final String DEFAULT_BASE_URL = "https://copernicus-dem-30m.s3.amazonaws.com";
    private static final double MAX_LAT = 50.0;

    private final HttpClient httpClient;
    private final Path cacheDir;
    private final Path mirrorDir;
    private final String baseUrl;
    private final int downloadAttempts;
    private final long retryBackoffMs;
    private boolean mirrorWarned;

    public DemService(
            @Value("${app.terrain.cache-dir:cache/dem}") String cacheDir,
            @Value("${app.terrain.mirror-dir:}") String mirrorDir,
            @Value("${app.terrain.aws.base-url:https://copernicus-dem-30m.s3.amazonaws.com}") String baseUrl,
            @Value("${app.terrain.download-attempts:4}") int downloadAttempts,
            @Value("${app.terrain.retry-backoff-ms:5000}") long retryBackoffMs
    ) {
        this.cacheDir = Path.of(cacheDir).resolve(CACHE_SUBDIR);
        this.mirrorDir = mirrorDir == null || mirrorDir.isBlank() ? null : Path.of(mirrorDir.trim());
        String base = baseUrl == null ? "" : baseUrl.trim();
        this.baseUrl = stripTrailingSlash(base.isEmpty() ? DEFAULT_BASE_URL : base);
        this.downloadAttempts = Math.max(1, downloadAttempts);
        this.retryBackoffMs = Math.max(0, retryBackoffMs);
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(20))
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
    }

    public record TerrainInfo(double[] box, int tiles, boolean fromCache, double downloadSeconds) {
    }

    public record Loaded(Terrain terrain, TerrainInfo info) {
    }

    private record Tile(GridTerrain terrain, boolean fromLocal) {
    }

    /** Relevo que cobre a caixa (graus). Sincronizado: o cache é compartilhado entre cálculos. */
    public synchronized Loaded load(double south, double north, double west, double east) throws IOException {
        validateBox(south, north, west, east);
        long t0 = System.nanoTime();
        boolean allLocal = true;
        List<GridTerrain> tiles = new ArrayList<>();
        for (String tile : tilesFor(south, north, west, east)) {
            Tile loaded = loadTile(tile);
            allLocal &= loaded.fromLocal();
            tiles.add(loaded.terrain());
        }
        double seconds = (System.nanoTime() - t0) / 1e9;
        Terrain terrain = tiles.size() == 1 ? tiles.get(0) : mosaic(tiles);
        return new Loaded(terrain, new TerrainInfo(new double[]{south, north, west, east}, tiles.size(), allLocal, seconds));
    }

    static List<String> tilesFor(double south, double north, double west, double east) {
        int latStart = (int) Math.floor(south);
        int latEnd = (int) Math.ceil(north) - 1;
        int lonStart = (int) Math.floor(west);
        int lonEnd = (int) Math.ceil(east) - 1;
        List<String> tiles = new ArrayList<>();
        for (int lat = latStart; lat <= latEnd; lat++) {
            for (int lon = lonStart; lon <= lonEnd; lon++) {
                tiles.add(tileName(lat, lon));
            }
        }
        return tiles;
    }

    static String tileName(int lat, int lon) {
        return String.format(Locale.US, "Copernicus_DSM_COG_10_%s%02d_00_%s%03d_00_DEM",
                lat >= 0 ? "N" : "S", Math.abs(lat), lon >= 0 ? "E" : "W", Math.abs(lon));
    }

    private static void validateBox(double south, double north, double west, double east) throws IOException {
        if (!Double.isFinite(south) || !Double.isFinite(north) || !Double.isFinite(west) || !Double.isFinite(east)) {
            throw new IOException("Caixa de relevo inválida: coordenadas não finitas.");
        }
        if (south >= north || west >= east) {
            throw new IOException("Caixa de relevo inválida: south < north e west < east são obrigatórios.");
        }
        if (south < -MAX_LAT || north > MAX_LAT) {
            throw new IOException("Caixa de relevo fora do domínio suportado: latitude deve ficar entre -50 e +50 "
                    + "(recebido south=" + south + ", north=" + north + ").");
        }
        if (west < -180.0 || east > 180.0) {
            throw new IOException("Caixa de relevo fora do domínio suportado: longitude deve ficar entre -180 e +180 "
                    + "(recebido west=" + west + ", east=" + east + ").");
        }
    }

    private Tile loadTile(String tile) throws IOException {
        Path cache = cachePath(tile);
        if (Files.isRegularFile(cache)) {
            try {
                return new Tile(GeoTiffReader.read(cache), true);
            } catch (IOException ex) {
                log.warn("Cache de relevo inválido para {}; baixando de novo: {}", tile, ex.getMessage());
                Files.deleteIfExists(cache);
            }
        }

        Path mirror = mirrorPath(tile);
        if (mirror != null) {
            try {
                copyToCache(mirror, cache);
                return new Tile(GeoTiffReader.read(cache), true);
            } catch (IOException ex) {
                log.warn("Mirror de relevo inválido para {}; tentando o S3: {}", tile, ex.getMessage());
                Files.deleteIfExists(cache);
            }
        }

        Path downloaded = download(tile);
        return new Tile(GeoTiffReader.read(downloaded), false);
    }

    private Path mirrorPath(String tile) {
        if (mirrorDir == null) return null;
        if (!Files.isDirectory(mirrorDir)) {
            if (!mirrorWarned) {
                log.warn("DEM_MIRROR_DIR configurado, mas o diretório {} não está disponível; usando o S3.", mirrorDir);
                mirrorWarned = true;
            }
            return null;
        }
        Path nested = mirrorDir.resolve(tile).resolve(tile + ".tif");
        if (Files.isRegularFile(nested)) return nested;
        Path flat = mirrorDir.resolve(tile + ".tif");
        return Files.isRegularFile(flat) ? flat : null;
    }

    private void copyToCache(Path source, Path target) throws IOException {
        Files.createDirectories(target.getParent());
        Path part = target.resolveSibling(target.getFileName() + ".part");
        Files.copy(source, part, StandardCopyOption.REPLACE_EXISTING);
        try {
            GeoTiffReader.read(part);
        } catch (IOException ex) {
            Files.deleteIfExists(part);
            throw ex;
        }
        Files.move(part, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    }

    private Path download(String tile) throws IOException {
        Path target = cachePath(tile);
        Files.createDirectories(target.getParent());
        String url = tileUrl(tile);
        Exception last = null;
        for (int attempt = 0; attempt < downloadAttempts; attempt++) {
            try {
                fetchTo(url, target, tile);
                last = null;
                break;
            } catch (Exception ex) {
                last = ex;
                log.warn("Falha ao baixar relevo {} (tentativa {}/{}): {}", tile, attempt + 1, downloadAttempts, ex.getMessage());
                if (ex instanceof InterruptedException) {
                    Thread.currentThread().interrupt();
                    break;
                }
                if (attempt + 1 < downloadAttempts) {
                    sleepQuietly(retryBackoffMs * (attempt + 1));
                }
            }
        }
        if (last != null) {
            throw new IOException("Não foi possível obter o relevo Copernicus GLO-30 do tile " + tile
                    + " em " + url + ": " + last.getMessage(), last);
        }
        return target;
    }

    private void fetchTo(String url, Path target, String tile) throws IOException, InterruptedException {
        Path part = target.resolveSibling(target.getFileName() + ".part");
        Files.deleteIfExists(part);
        HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(300))
                .header("Accept", "image/tiff, application/octet-stream")
                .GET().build();
        HttpResponse<Path> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofFile(part,
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE));
        if (resp.statusCode() != 200) {
            String snippet = readSnippet(part);
            Files.deleteIfExists(part);
            throw new IOException("HTTP " + resp.statusCode() + " para " + url
                    + (snippet.isEmpty() ? "" : ": " + snippet));
        }
        try {
            GeoTiffReader.read(part);
        } catch (IOException ex) {
            Files.deleteIfExists(part);
            throw new IOException("Arquivo de relevo inválido para o tile " + tile + ": " + ex.getMessage(), ex);
        }
        Files.move(part, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    }

    private Path cachePath(String tile) {
        return cacheDir.resolve(tile).resolve(tile + ".tif");
    }

    private String tileUrl(String tile) {
        return baseUrl + "/" + tile + "/" + tile + ".tif";
    }

    static GridTerrain mosaic(List<GridTerrain> blocks) {
        double dx = blocks.get(0).dx();
        double dy = blocks.get(0).dy();
        double lon0 = Double.POSITIVE_INFINITY;
        double lat0 = Double.NEGATIVE_INFINITY;
        double lonEnd = Double.NEGATIVE_INFINITY;
        double latEnd = Double.POSITIVE_INFINITY;
        for (GridTerrain b : blocks) {
            if (Math.abs(b.dx() - dx) > 1e-12 || Math.abs(b.dy() - dy) > 1e-12) {
                throw new IllegalArgumentException("Tiles de relevo com resoluções diferentes.");
            }
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
        return new GridTerrain(z, h, w, lon0, lat0, dx, dy, "Copernicus GLO-30:mosaico " + blocks.size() + " tiles");
    }

    private static String stripTrailingSlash(String value) {
        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }

    private static String readSnippet(Path file) {
        try (InputStream in = Files.newInputStream(file)) {
            return new String(in.readNBytes(200), StandardCharsets.UTF_8).replaceAll("\\s+", " ").trim();
        } catch (IOException ex) {
            return "";
        }
    }

    private static void sleepQuietly(long ms) {
        if (ms <= 0) return;
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
