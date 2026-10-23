package com.tecsys.domain.decision.service;

public class FlatElevationRaster implements AreaElevationRaster {

    private final double defaultElevation;

    public FlatElevationRaster() {
        this(0.0);
    }

    public FlatElevationRaster(double defaultElevation) {
        this.defaultElevation = defaultElevation;
    }

    @Override
    public double getElevation(double latitude, double longitude) {
        return defaultElevation;
    }

    @Override
    public void close() {
        // Nada a limpar para raster plano
    }
}

