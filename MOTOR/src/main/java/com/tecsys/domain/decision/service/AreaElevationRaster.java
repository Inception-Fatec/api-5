package com.tecsys.domain.decision.service;

@FunctionalInterface
public interface AreaElevationRaster extends AutoCloseable {

    /**
     * Retorna a elevação (em metros) na coordenada geográfica informada.
     */
    double getElevation(double latitude, double longitude);

    @Override
    default void close() {
        // Implementação padrão vazia para facilitar mocks e rasters sem arquivo temporário
    }
}

