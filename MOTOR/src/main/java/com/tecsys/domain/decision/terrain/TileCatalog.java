package com.tecsys.domain.decision.terrain;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;
import java.util.zip.GZIPInputStream;

/**
 * Catálogo dos tiles do Copernicus DEM GLO-30 que existem no bucket da AWS.
 *
 * <p>O bucket só tem tiles com terra: um tile 100% oceano não existe e o S3 responde 404 (ex.:
 * {@code S24_W041}, no mar ao largo do RJ). Com o catálogo, o motor sabe de antemão que o tile é
 * mar e usa 0 m sem chamar o S3. Um 404 de tile que <b>está</b> no catálogo continua sendo erro.
 *
 * <p>Fonte: {@code https://copernicus-dem-30m.s3.amazonaws.com/tileList.txt} (26.450 tiles),
 * guardado compactado em {@code resources/dem/copernicus-glo30-tilelist.txt.gz}.
 */
public final class TileCatalog {

    static final String RESOURCE = "/dem/copernicus-glo30-tilelist.txt.gz";

    private static final Set<String> TILES = load();

    private TileCatalog() {
    }

    /** O tile existe no bucket (tem terra). */
    public static boolean contains(String tile) {
        return TILES.contains(tile);
    }

    public static int size() {
        return TILES.size();
    }

    private static Set<String> load() {
        try (InputStream raw = TileCatalog.class.getResourceAsStream(RESOURCE)) {
            if (raw == null) {
                throw new IllegalStateException("Catálogo de tiles do Copernicus não encontrado: " + RESOURCE);
            }
            Set<String> tiles = new HashSet<>(32_768);
            try (BufferedReader in = new BufferedReader(
                    new InputStreamReader(new GZIPInputStream(raw), StandardCharsets.UTF_8))) {
                String line;
                while ((line = in.readLine()) != null) {
                    String tile = line.trim();
                    if (!tile.isEmpty()) tiles.add(tile);
                }
            }
            return Set.copyOf(tiles);
        } catch (IOException e) {
            throw new UncheckedIOException("Falha ao ler o catálogo de tiles do Copernicus", e);
        }
    }
}
