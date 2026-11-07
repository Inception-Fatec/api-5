package com.tecsys.domain.decision.terrain;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DemServiceTest {

    private static final double PX = 0.25 / 4;
    private static final String TILE = "Copernicus_DSM_COG_10_S23_00_W046_00_DEM";
    private static final String FIXTURE = "/dem/aws-copernicus/S23_00_W046_00_campos_cog.tif";

    @TempDir
    Path tmp;

    private static GridTerrain block(double lon0, double lat0, float value) {
        float[] z = new float[16];
        java.util.Arrays.fill(z, value);
        return new GridTerrain(z, 4, 4, lon0, lat0, PX, PX, "bloco");
    }

    private static GridTerrain tileBlock(double lon0, double lat0, float value) {
        float[] z = new float[16];
        java.util.Arrays.fill(z, value);
        return new GridTerrain(z, 4, 4, lon0, lat0, 0.25, 0.25, "tile");
    }

    private static Path fixture() throws Exception {
        return Path.of(DemServiceTest.class.getResource(FIXTURE).toURI());
    }

    private static byte[] fixtureBytes() throws Exception {
        return Files.readAllBytes(fixture());
    }

    private static void copyFixture(Path target) throws Exception {
        Files.createDirectories(target.getParent());
        Files.copy(fixture(), target);
    }

    private DemService service(Path cache, Path mirror, String baseUrl, int attempts) {
        return new DemService(cache.toString(), mirror == null ? "" : mirror.toString(), baseUrl, attempts, 0);
    }

    @Test
    void mosaicoJuntaBlocosVizinhosSemSobreposicao() {
        GridTerrain nw = block(-46.00, -23.00, 100);
        GridTerrain ne = block(-45.75, -23.00, 200);
        GridTerrain sw = block(-46.00, -23.25, 300);
        GridTerrain se = block(-45.75, -23.25, 400);

        GridTerrain m = DemService.mosaic(List.of(sw, se, nw, ne));

        assertEquals(8, m.width());
        assertEquals(8, m.height());
        assertEquals(100, m.sampleNearest(-23.01, -45.99), 1e-6);
        assertEquals(200, m.sampleNearest(-23.01, -45.70), 1e-6);
        assertEquals(300, m.sampleNearest(-23.30, -45.99), 1e-6);
        assertEquals(400, m.sampleNearest(-23.30, -45.70), 1e-6);
    }


    @Test
    void mosaicoDeTilesDeUmGrau() {
        GridTerrain nw = tileBlock(-46.00, -22.00, 100);
        GridTerrain ne = tileBlock(-45.00, -22.00, 200);
        GridTerrain sw = tileBlock(-46.00, -23.00, 300);
        GridTerrain se = tileBlock(-45.00, -23.00, 400);

        GridTerrain m = DemService.mosaic(List.of(sw, se, nw, ne));

        assertEquals(8, m.width());
        assertEquals(8, m.height());
        assertEquals(100, m.sampleNearest(-22.01, -45.99), 1e-6);
        assertEquals(200, m.sampleNearest(-22.01, -45.01), 1e-6);
        assertEquals(300, m.sampleNearest(-23.01, -45.99), 1e-6);
        assertEquals(400, m.sampleNearest(-23.01, -45.01), 1e-6);
    }

    @Test
    void nomeDoTileSegueOPadraoDoAws() {
        assertEquals(TILE, DemService.tileName(-23, -46));
        assertEquals("Copernicus_DSM_COG_10_N00_00_E000_00_DEM", DemService.tileName(0, 0));
        assertEquals("Copernicus_DSM_COG_10_S50_00_W180_00_DEM", DemService.tileName(-50, -180));
        assertEquals("Copernicus_DSM_COG_10_N49_00_E179_00_DEM", DemService.tileName(49, 179));
    }

    @Test
    void enumeraTilesCobertosPelaCaixa() {
        assertEquals(List.of(
                        "Copernicus_DSM_COG_10_S24_00_W047_00_DEM",
                        "Copernicus_DSM_COG_10_S24_00_W046_00_DEM",
                        "Copernicus_DSM_COG_10_S23_00_W047_00_DEM",
                        "Copernicus_DSM_COG_10_S23_00_W046_00_DEM"),
                DemService.tilesFor(-23.37, -22.93, -46.07, -45.53));
    }

    @Test
    void incluiTilesDeTodosOsLadosQuandoACaixaCruzaGrausInteiros() {
        assertEquals(List.of(
                        "Copernicus_DSM_COG_10_S24_00_W046_00_DEM",
                        "Copernicus_DSM_COG_10_S24_00_W045_00_DEM",
                        "Copernicus_DSM_COG_10_S23_00_W046_00_DEM",
                        "Copernicus_DSM_COG_10_S23_00_W045_00_DEM"),
                DemService.tilesFor(-23.0001, -22.9999, -45.0001, -44.9999));
        assertEquals(List.of("Copernicus_DSM_COG_10_S24_00_W046_00_DEM"),
                DemService.tilesFor(-24.0, -23.0, -46.0, -45.0));
    }

    @Test
    void rejeitaLatitudeForaDoDominio() {
        DemService s = service(tmp.resolve("cache"), null, "http://127.0.0.1:1", 1);
        IOException ex = assertThrows(IOException.class, () -> s.load(49.0, 51.0, -46.0, -45.0));
        assertTrue(ex.getMessage().contains("-50 e +50"));
    }

    @Test
    void rejeitaAntimeridiano() {
        DemService s = service(tmp.resolve("cache"), null, "http://127.0.0.1:1", 1);
        IOException ex = assertThrows(IOException.class, () -> s.load(-23.0, -22.0, 170.0, -170.0));
        assertTrue(ex.getMessage().contains("west < east"));
    }

    @Test
    void usaCacheSemRede() throws Exception {
        Path cache = tmp.resolve("cache");
        copyFixture(cache.resolve("aws-copernicus").resolve(TILE).resolve(TILE + ".tif"));
        DemService s = service(cache, null, "http://127.0.0.1:1", 1);

        DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

        assertEquals(181, ((GridTerrain) loaded.terrain()).width());
        assertEquals(1, loaded.info().tiles());
        assertTrue(loaded.info().fromCache());
        assertTrue(loaded.terrain().source().contains(TILE));
    }

    @Test
    void copiaMirrorParaOCacheAntesDeLer() throws Exception {
        Path cache = tmp.resolve("cache");
        Path mirror = tmp.resolve("mirror");
        Path mirrored = mirror.resolve(TILE).resolve(TILE + ".tif");
        copyFixture(mirrored);
        DemService s = service(cache, mirror, "http://127.0.0.1:1", 1);

        DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

        Path cached = cache.resolve("aws-copernicus").resolve(TILE).resolve(TILE + ".tif");
        assertTrue(Files.isRegularFile(cached));
        assertArrayEquals(Files.readAllBytes(mirrored), Files.readAllBytes(cached));
        assertEquals(181, ((GridTerrain) loaded.terrain()).width());
        assertTrue(loaded.info().fromCache());
    }

    @Test
    void aceitaLayoutPlanoNoMirror() throws Exception {
        Path cache = tmp.resolve("cache");
        Path mirror = tmp.resolve("mirror");
        copyFixture(mirror.resolve(TILE + ".tif"));
        DemService s = service(cache, mirror, "http://127.0.0.1:1", 1);

        DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

        assertEquals(181, ((GridTerrain) loaded.terrain()).width());
        assertTrue(loaded.info().fromCache());
    }

    @Test
    void cacheCorrompidoCaiParaOMirror() throws Exception {
        Path cache = tmp.resolve("cache");
        Path corrupt = cache.resolve("aws-copernicus").resolve(TILE).resolve(TILE + ".tif");
        Files.createDirectories(corrupt.getParent());
        Files.writeString(corrupt, "corrompido");
        Path mirror = tmp.resolve("mirror");
        copyFixture(mirror.resolve(TILE).resolve(TILE + ".tif"));
        DemService s = service(cache, mirror, "http://127.0.0.1:1", 1);

        DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

        assertEquals(181, ((GridTerrain) loaded.terrain()).width());
        assertTrue(Files.size(corrupt) > 1000);
    }

    @Test
    void mirrorIndisponivelCaiParaOS3() throws Exception {
        Path cache = tmp.resolve("cache");
        try (StubServer server = new StubServer(0, 200, fixtureBytes())) {
            DemService s = service(cache, tmp.resolve("nao-montado"), server.baseUrl(), 1);

            DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

            assertEquals(181, ((GridTerrain) loaded.terrain()).width());
            assertFalse(loaded.info().fromCache());
            assertEquals(1, server.calls.get());
        }
    }

    @Test
    void mirrorCorrompidoCaiParaOS3() throws Exception {
        Path cache = tmp.resolve("cache");
        Path mirror = tmp.resolve("mirror");
        Path corrupt = mirror.resolve(TILE).resolve(TILE + ".tif");
        Files.createDirectories(corrupt.getParent());
        Files.writeString(corrupt, "corrompido");
        try (StubServer server = new StubServer(0, 200, fixtureBytes())) {
            DemService s = service(cache, mirror, server.baseUrl(), 1);

            DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

            assertEquals(181, ((GridTerrain) loaded.terrain()).width());
            assertFalse(loaded.info().fromCache());
            assertEquals(1, server.calls.get());
        }
    }

    @Test
    void baixaValidaEGravaNoCache() throws Exception {
        Path cache = tmp.resolve("cache");
        try (StubServer server = new StubServer(0, 200, fixtureBytes())) {
            DemService s = service(cache, null, server.baseUrl(), 1);

            DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

            Path cached = cache.resolve("aws-copernicus").resolve(TILE).resolve(TILE + ".tif");
            assertTrue(Files.isRegularFile(cached));
            assertEquals(181, ((GridTerrain) loaded.terrain()).width());
            assertFalse(loaded.info().fromCache());
            assertEquals(1, server.calls.get());
        }
    }

    @Test
    void tentaDeNovoDepoisDeErro500() throws Exception {
        Path cache = tmp.resolve("cache");
        try (StubServer server = new StubServer(2, 200, fixtureBytes())) {
            DemService s = service(cache, null, server.baseUrl(), 3);

            DemService.Loaded loaded = s.load(-22.70, -22.65, -45.60, -45.55);

            assertEquals(181, ((GridTerrain) loaded.terrain()).width());
            assertEquals(3, server.calls.get());
        }
    }

    @Test
    void erro404FalhaComMensagemDoTile() throws Exception {
        Path cache = tmp.resolve("cache");
        try (StubServer server = new StubServer(0, 404, "not found".getBytes(StandardCharsets.UTF_8))) {
            DemService s = service(cache, null, server.baseUrl(), 1);

            IOException ex = assertThrows(IOException.class, () -> s.load(-22.70, -22.65, -45.60, -45.55));

            assertTrue(ex.getMessage().contains(TILE));
            assertTrue(ex.getMessage().contains("404"));
            assertFalse(Files.exists(cache.resolve("aws-copernicus").resolve(TILE).resolve(TILE + ".tif")));
        }
    }

    @Test
    void erroDeConexaoFalhaComMensagemNaoNula() throws Exception {
        Path cache = tmp.resolve("cache");
        DemService s = service(cache, null, "http://127.0.0.1:1", 1);

        IOException ex = assertThrows(IOException.class, () -> s.load(-22.70, -22.65, -45.60, -45.55));

        assertTrue(ex.getMessage().contains(TILE), ex.getMessage());
        assertTrue(ex.getMessage().contains("ConnectException"), ex.getMessage());
        assertFalse(ex.getMessage().endsWith("null"), ex.getMessage());
    }

    @Test
    void corpoQueNaoETiffFalhaSemCachear() throws Exception {
        Path cache = tmp.resolve("cache");
        try (StubServer server = new StubServer(0, 200, "nao e tiff".getBytes(StandardCharsets.UTF_8))) {
            DemService s = service(cache, null, server.baseUrl(), 1);

            IOException ex = assertThrows(IOException.class, () -> s.load(-22.70, -22.65, -45.60, -45.55));

            assertTrue(ex.getMessage().contains("inválido"));
            assertFalse(Files.exists(cache.resolve("aws-copernicus").resolve(TILE).resolve(TILE + ".tif")));
        }
    }

    private static final class StubServer implements AutoCloseable {

        private final HttpServer server;
        private final AtomicInteger calls = new AtomicInteger();

        private StubServer(int failures, int status, byte[] body) throws IOException {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            server.createContext("/", exchange -> {
                int call = calls.incrementAndGet();
                if (call <= failures) {
                    exchange.sendResponseHeaders(500, -1);
                    exchange.close();
                    return;
                }
                exchange.getResponseHeaders().add("Content-Type", "image/tiff");
                exchange.sendResponseHeaders(status, body.length);
                try (OutputStream out = exchange.getResponseBody()) {
                    out.write(body);
                }
            });
            server.start();
        }

        private String baseUrl() {
            return "http://127.0.0.1:" + server.getAddress().getPort();
        }

        @Override
        public void close() {
            server.stop(0);
        }
    }
}
