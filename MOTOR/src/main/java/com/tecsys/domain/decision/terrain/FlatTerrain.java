package com.tecsys.domain.decision.terrain;

/** Terreno plano na cota zero. Só é usado quando o relevo está desligado de propósito. */
public final class FlatTerrain implements Terrain {

    @Override
    public double sample(double lat, double lon) {
        return 0.0;
    }

    @Override
    public double sampleNearest(double lat, double lon) {
        return 0.0;
    }

    @Override
    public String source() {
        return "plano";
    }

    @Override
    public double minElevation() {
        return 0.0;
    }

    @Override
    public double maxElevation() {
        return 0.0;
    }
}
