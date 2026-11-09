package com.tecsys.domain.decision.terrain;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("network")
class DemServiceNetworkTest {

    @TempDir
    Path tmp;

    @Test
    void baixaUmTileRealDoAwsELeEmFloat32() throws Exception {
        DemService service = new DemService(tmp.toString(), "", "https://copernicus-dem-30m.s3.amazonaws.com", 1, 0);

        DemService.Loaded loaded = service.load(-22.70, -22.65, -45.60, -45.55);

        assertEquals(3600, ((GridTerrain) loaded.terrain()).width());
        assertEquals(3600, ((GridTerrain) loaded.terrain()).height());
        assertTrue(loaded.terrain().source().contains("S23_00_W046_00"));
        assertTrue(loaded.terrain().minElevation() > 0);
        assertTrue(loaded.terrain().maxElevation() > loaded.terrain().minElevation());
    }
}
