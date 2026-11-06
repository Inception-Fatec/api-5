package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.terrain.Terrain;

import java.util.Arrays;

/**
 * Viewshed por raios a partir de um gateway, com curvatura da Terra.
 *
 * <p>Lança até ~8 mil raios e acumula, ao longo de cada um, o maior ângulo de elevação do terreno.
 * Um ponto é visível se o ângulo até ele supera esse horizonte. Só são calculados os raios que
 * contêm pontos, e só até o ponto mais distante. O custo cresce com a área, não com o número de
 * pares: é isso que torna viável o alcance de ~19 km do modelo do parceiro.
 *
 * <p>Não é thread-safe (reaproveita buffers): use uma instância por thread.
 */
public final class RayViewshed {

    private final Terrain terrain;
    private final Geo.LocalProjection proj;
    private final double step;
    private final double k;
    private final boolean curvature;
    private final int nRays;
    private final int nSteps;
    private final double[] sin;
    private final double[] cos;
    private final double[] drop;
    private final double[] horizon;

    public RayViewshed(Terrain terrain, Geo.LocalProjection proj, double radiusM, double step, double k, boolean curvature) {
        this.terrain = terrain;
        this.proj = proj;
        this.step = step;
        this.k = k;
        this.curvature = curvature;
        this.nRays = (int) Math.min(8192, Math.max(360, Math.ceil(2 * Math.PI * radiusM / step)));
        this.nSteps = (int) Math.ceil(radiusM / step);
        this.sin = new double[nRays];
        this.cos = new double[nRays];
        for (int r = 0; r < nRays; r++) {
            double th = r * (2 * Math.PI / nRays);
            sin[r] = Math.sin(th);
            cos[r] = Math.cos(th);
        }
        this.drop = new double[nSteps];
        for (int j = 0; j < nSteps; j++) {
            double s = (j + 1) * step;
            drop[j] = curvature ? s * s / (2 * k * Radio.EARTH_RADIUS_M) : 0.0;
        }
        this.horizon = new double[nSteps];
    }

    /**
     * Marca em {@code out[i]} se o ponto {@code idx[i]} é visível do gateway.
     *
     * @param gz terreno + altura do gateway
     * @param pz terreno + altura de cada ponto
     */
    public void visible(double gx, double gy, double gz, int[] idx, int n,
                        double[] px, double[] py, double[] pz, double tol, boolean[] out) {
        int[] ray = new int[n];
        int[] upTo = new int[n];
        double[] target = new double[n];
        double invTwoKR = curvature ? 1.0 / (2 * k * Radio.EARTH_RADIUS_M) : 0.0;

        long[] order = new long[n];
        for (int i = 0; i < n; i++) {
            int p = idx[i];
            double vx = px[p] - gx;
            double vy = py[p] - gy;
            double d = Math.hypot(vx, vy);
            double az = Math.atan2(vx, vy);
            if (az < 0) az += 2 * Math.PI;
            ray[i] = (int) (((long) Math.rint(az / (2 * Math.PI) * nRays)) % nRays);
            // amostras estritamente antes do ponto (descarta a célula do próprio ponto)
            upTo[i] = (int) Math.min(Math.floor(d / step - 0.5), nSteps);
            double dd = Math.max(d, 1e-6);
            target[i] = (pz[p] - d * d * invTwoKR - gz) / dd + tol / dd;
            order[i] = ((long) ray[i] << 32) | i;
        }
        Arrays.sort(order);

        int a = 0;
        while (a < n) {
            int r = (int) (order[a] >>> 32);
            int b = a;
            int maxM = 0;
            while (b < n && (int) (order[b] >>> 32) == r) {
                maxM = Math.max(maxM, upTo[(int) order[b]]);
                b++;
            }
            if (maxM >= 1) {
                double best = Double.NEGATIVE_INFINITY;
                for (int j = 0; j < maxM; j++) {
                    double s = (j + 1) * step;
                    double lat = proj.lat(gy + cos[r] * s);
                    double lon = proj.lon(gx + sin[r] * s);
                    double ang = (terrain.sample(lat, lon) - drop[j] - gz) / s;
                    if (ang > best) best = ang;
                    horizon[j] = best;
                }
            }
            for (int q = a; q < b; q++) {
                int i = (int) order[q];
                out[i] = upTo[i] < 1 || target[i] >= horizon[upTo[i] - 1];
            }
            a = b;
        }
    }
}
