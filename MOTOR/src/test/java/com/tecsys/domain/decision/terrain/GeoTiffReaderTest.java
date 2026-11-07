package com.tecsys.domain.decision.terrain;

import org.junit.jupiter.api.Test;

import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GeoTiffReaderTest {

    private static final double PIXEL = 1.0 / 3600.0;

    /**
     * Arquivo no formato do COP30 (float32, LZW, blocos de 256, PixelIsPoint, nodata −32767),
     * com valor conhecido z = 500 + 2·linha + 0,5·coluna + 0,25 e o pixel [0,0] sem dado.
     */
    private static GridTerrain fixture() throws Exception {
        Path p = Path.of(GeoTiffReaderTest.class.getResource("/dem/sintetico_float32_lzw.tif").toURI());
        return GeoTiffReader.read(p);
    }

    @Test
    void leValoresEmMetrosEmVezDeCinzaDe8Bits() throws Exception {
        GridTerrain t = fixture();

        assertEquals(280, t.width());
        assertEquals(300, t.height());
        // pixel (linha 10, coluna 20) e um pixel no segundo bloco de 256 (linha 290, coluna 270)
        assertEquals(530.25, t.sampleNearest(-23.0 - 10 * PIXEL, -45.5 + 20 * PIXEL), 1e-3);
        assertEquals(500 + 580 + 135 + 0.25, t.sampleNearest(-23.0 - 290 * PIXEL, -45.5 + 270 * PIXEL), 1e-3);
    }

    @Test
    void georreferenciaPixelIsPoint() throws Exception {
        GridTerrain t = fixture();

        assertEquals(-45.5, t.lon0(), 1e-9);
        assertEquals(-23.0, t.lat0(), 1e-9);
        assertEquals(PIXEL, t.dx(), 1e-12);
    }

    @Test
    void interpolacaoBilinearEntrePixels() throws Exception {
        GridTerrain t = fixture();

        // meio caminho entre as linhas 10 e 11 e entre as colunas 20 e 21: função linear, valor exato
        double z = t.sample(-23.0 - 10.5 * PIXEL, -45.5 + 20.5 * PIXEL);
        assertEquals(500 + 21 + 10.25 + 0.25, z, 1e-3);
    }

    @Test
    void semDadoRecebeMedianaDosValidos() throws Exception {
        GridTerrain t = fixture();

        double z00 = t.sampleNearest(-23.0, -45.5);
        assertEquals(true, z00 > 500 && z00 < 1300, "nodata deve virar a mediana, não −32767: " + z00);
    }
}
