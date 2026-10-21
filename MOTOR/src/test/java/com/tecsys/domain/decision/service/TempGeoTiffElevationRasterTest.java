package com.tecsys.domain.decision.service;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class TempGeoTiffElevationRasterTest {

    @Test
    void shouldDeleteTempFileOnClose() throws IOException {
        Path tempFile = Files.createTempFile("test_dem_", ".tif");
        assertTrue(Files.exists(tempFile));

        try (TempGeoTiffElevationRaster raster = new TempGeoTiffElevationRaster(tempFile, -23.5, -23.0, -46.0, -45.5)) {
            assertTrue(Files.exists(tempFile));
        }

        // Após sair do bloco try-with-resources, o arquivo temporário deve ter sido excluído
        assertFalse(Files.exists(tempFile));
    }
}

