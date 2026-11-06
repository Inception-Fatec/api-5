package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.terrain.GridTerrain;
import org.junit.jupiter.api.Test;

import java.util.Random;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LineOfSightTest {

    private static final double K = 4.0 / 3.0;

    private static boolean profile(GridTerrain t, double glat, double glon, double gh,
                                   double plat, double plon, double ph, double step) {
        double d = Geo.haversineM(glat, glon, plat, plon);
        return LineOfSight.profile(t, glat, glon, t.sample(glat, glon) + gh, plat, plon,
                t.sample(plat, plon) + ph, d, step, 0.0, true, K, 0.0, 915.0);
    }

    @Test
    void perfilDetectaMorroQueCincoAmostrasPerdem() {
        GridTerrain t = Terrains.ridge(100);
        // enlace cruzando o morro fino a ~37% do caminho: as amostras de 20/40/60/80% não caem nele
        double lat = -23.05;
        double glon = -45.95 - 0.37 * 0.05;
        double plon = glon + 0.05;
        assertFalse(profile(t, lat, glon, 6, lat, plon, 5, 30));
        assertTrue(LineOfSight.team(t, lat, glon, 6, lat, plon, 5, 5, 0.0), "o método antigo não vê o morro");
    }

    @Test
    void visadaLivreEmTerrenoPlanoCurto() {
        GridTerrain t = Terrains.flat(50, -46, -23, Terrains.PIXEL);
        assertTrue(profile(t, -23.001, -45.999, 6, -23.010, -45.990, 5, 30));
    }

    @Test
    void curvaturaDaTerraBloqueiaAlemDoHorizonte() {
        GridTerrain t = Terrains.flat(10, -46, -22, 1);
        double dlat = 25_000.0 / 111_195.0; // 25 km > horizonte de 19,3 km para 6 m / 5 m
        assertFalse(profile(t, -23.0, -45.0, 6, -23.0 + dlat, -45.0, 5, 100));
        assertTrue(profile(t, -23.0, -45.0, 6, -23.0 + dlat * 0.6, -45.0, 5, 100));
    }

    @Test
    void viewshedPorRaiosConcordaComPerfil() {
        GridTerrain t = Terrains.ridge(80);
        Geo.LocalProjection proj = new Geo.LocalProjection(-23.05, -45.95);
        Random rng = new Random(1);
        int n = 300;
        double[] plat = new double[n], plon = new double[n], px = new double[n], py = new double[n], pz = new double[n];
        for (int i = 0; i < n; i++) {
            plat[i] = -23.05 + (rng.nextDouble() * 2 - 1) * 0.03;
            plon[i] = -45.95 + (rng.nextDouble() * 2 - 1) * 0.04;
            px[i] = proj.x(plon[i]);
            py[i] = proj.y(plat[i]);
            pz[i] = t.sample(plat[i], plon[i]) + 5;
        }
        double glat = -23.05, glon = -45.975;
        double gx = proj.x(glon), gy = proj.y(glat), gz = t.sample(glat, glon) + 6;
        int[] near = new int[n];
        int m = 0;
        for (int i = 0; i < n; i++) if (Math.hypot(px[i] - gx, py[i] - gy) <= 6000) near[m++] = i;
        boolean[] rays = new boolean[m];
        new RayViewshed(t, proj, 6000, 30, K, true).visible(gx, gy, gz, near, m, px, py, pz, 0.0, rays);

        int agree = 0, blocked = 0;
        for (int i = 0; i < m; i++) {
            int q = near[i];
            boolean prof = profile(t, glat, glon, 6, plat[q], plon[q], 5, 30);
            if (prof == rays[i]) agree++;
            if (!prof) blocked++;
        }
        assertTrue(blocked > 20, "o morro precisa bloquear parte dos pontos: " + blocked);
        assertTrue(agree > 0.97 * m, "concordância " + agree + "/" + m);
    }
}
