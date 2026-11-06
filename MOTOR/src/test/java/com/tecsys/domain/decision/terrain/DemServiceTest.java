package com.tecsys.domain.decision.terrain;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class DemServiceTest {

    private static final double PX = 0.25 / 4; // 4 px por bloco de 0,25°, PixelIsPoint

    private static GridTerrain block(double lon0, double lat0, float value) {
        float[] z = new float[16];
        java.util.Arrays.fill(z, value);
        return new GridTerrain(z, 4, 4, lon0, lat0, PX, PX, "bloco");
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
}
