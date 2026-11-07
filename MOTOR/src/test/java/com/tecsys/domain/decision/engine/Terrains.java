package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.terrain.GridTerrain;

/** Relevos sintéticos para os testes. */
final class Terrains {

    static final double PIXEL = 1.0 / 3600.0;

    private Terrains() {
    }

    /** Grade de 0,1° com 1 arco-segundo (~30 m) e um morro fino (5 px) em lon ≈ −45,95. */
    static GridTerrain ridge(double height) {
        int n = 360;
        float[] z = new float[n * n];
        for (int i = 0; i < n; i++) {
            for (int j = n / 2 - 2; j < n / 2 + 3; j++) z[i * n + j] = (float) height;
        }
        return new GridTerrain(z, n, n, -46.0, -23.0, PIXEL, PIXEL, "teste");
    }

    static GridTerrain flat(int n, double lon0, double lat0, double step) {
        return new GridTerrain(new float[n * n], n, n, lon0, lat0, step, step, "plano");
    }
}
