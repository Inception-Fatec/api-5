package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.terrain.Terrain;

/**
 * Visada entre duas antenas sobre o relevo.
 * <ul>
 *   <li>{@link #team}: réplica do motor antigo (poucas amostras, pixel mais próximo, folga).</li>
 *   <li>{@link #profile}: perfil amostrado a cada {@code step} metros, bilinear, curvatura da
 *       Terra e, opcionalmente, uma fração da 1ª zona de Fresnel.</li>
 * </ul>
 * O viewshed por raios fica em {@link RayViewshed}.
 */
public final class LineOfSight {

    private LineOfSight() {
    }

    public static boolean team(Terrain t, double glat, double glon, double gh,
                               double plat, double plon, double ph, int samples, double tol) {
        double z0 = t.sampleNearest(glat, glon) + gh;
        double z1 = t.sampleNearest(plat, plon) + ph;
        int s = Math.max(2, samples);
        for (int i = 1; i < s; i++) {
            double f = (double) i / s;
            double line = z0 + f * (z1 - z0);
            if (t.sampleNearest(glat + f * (plat - glat), glon + f * (plon - glon)) > line + tol) {
                return false;
            }
        }
        return true;
    }

    /**
     * @param dist distância entre as antenas (m)
     * @param z0   terreno + altura no gateway
     * @param z1   terreno + altura no ponto
     */
    public static boolean profile(Terrain t, double glat, double glon, double z0,
                                  double plat, double plon, double z1, double dist,
                                  double step, double tol, boolean curvature, double k,
                                  double fresnelFraction, double freqMhz) {
        int n = (int) Math.max(Math.ceil(dist / step), 1); // nº de segmentos
        double curv = curvature ? 1.0 / (2.0 * k * Radio.EARTH_RADIUS_M) : 0.0;
        for (int i = 1; i < n; i++) {
            double f = (double) i / n;
            double terrain = t.sample(glat + f * (plat - glat), glon + f * (plon - glon));
            double d1 = f * dist;
            double d2 = dist - d1;
            terrain += d1 * d2 * curv;
            if (fresnelFraction > 0) {
                terrain += fresnelFraction * Radio.fresnelRadiusM(d1, d2, freqMhz);
            }
            if (terrain > z0 + f * (z1 - z0) + tol) {
                return false;
            }
        }
        return true;
    }
}
