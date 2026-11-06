package com.tecsys.domain.decision.terrain;

/** Modelo de elevação do terreno, em metros. */
public interface Terrain {

    /** Interpolação bilinear. */
    double sample(double lat, double lon);

    /** Pixel mais próximo (como o motor antigo). */
    double sampleNearest(double lat, double lon);

    String source();

    double minElevation();

    double maxElevation();
}
