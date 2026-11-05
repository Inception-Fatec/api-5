package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.terrain.Terrain;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Arrays;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ForkJoinPool;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

/**
 * Monta a matriz de cobertura (locais de ponto × locais de candidato): um par entra na matriz se
 * está dentro do raio de busca, tem visada sobre o relevo e, sem alcance fixo, se a perda em
 * espaço livre cabe no orçamento de enlace. Os candidatos são processados em paralelo.
 */
public final class CoverageBuilder {

    private static final Logger log = LoggerFactory.getLogger(CoverageBuilder.class);

    /** Locais únicos (lat, lon, altura da antena). */
    public record Sites(double[] lat, double[] lon, double[] height) {
        public int size() {
            return lat.length;
        }
    }

    private CoverageBuilder() {
    }

    public static CoverageMatrix build(MotorParams p, Terrain terrain, Geo.LocalProjection proj,
                                       Sites pts, Sites cands, double radius, int threads) {
        int np = pts.size();
        int nc = cands.size();
        double[] px = new double[np];
        double[] py = new double[np];
        double[] pz = new double[np];
        for (int i = 0; i < np; i++) {
            px[i] = proj.x(pts.lon()[i]);
            py[i] = proj.y(pts.lat()[i]);
            pz[i] = terrain.sample(pts.lat()[i], pts.lon()[i]) + pts.height()[i];
        }
        double[] cx = new double[nc];
        double[] cy = new double[nc];
        double[] cz = new double[nc];
        for (int c = 0; c < nc; c++) {
            cx[c] = proj.x(cands.lon()[c]);
            cy[c] = proj.y(cands.lat()[c]);
            cz[c] = terrain.sample(cands.lat()[c], cands.lon()[c]) + cands.height()[c];
        }
        PointGrid grid = new PointGrid(px, py, radius);
        double budget = Radio.budgetDb(p);
        boolean checkBudget = p.fixedRangeM() == null;

        int[][] columns = new int[nc][];
        AtomicInteger done = new AtomicInteger();
        int logEvery = Math.max(1, nc / 10);
        ThreadLocal<RayViewshed> viewshed = ThreadLocal.withInitial(() ->
                new RayViewshed(terrain, proj, radius, p.losStepM(), p.kFactor(), p.earthCurvature()));

        ForkJoinPool pool = new ForkJoinPool(Math.max(1, threads));
        try {
            pool.submit(() -> IntStream.range(0, nc).parallel().forEach(c -> {
                int[] near = grid.within(cx[c], cy[c], radius);
                int n = near.length;
                boolean[] ok = new boolean[n];
                double[] dist = new double[n];
                if (p.lineOfSight() == MotorParams.LosMode.RAYS) {
                    viewshed.get().visible(cx[c], cy[c], cz[c], near, n, px, py, pz, p.obstructionToleranceM(), ok);
                    for (int i = 0; i < n; i++) dist[i] = Math.hypot(px[near[i]] - cx[c], py[near[i]] - cy[c]);
                } else {
                    double glat = cands.lat()[c];
                    double glon = cands.lon()[c];
                    for (int i = 0; i < n; i++) {
                        int q = near[i];
                        double d = Geo.haversineM(glat, glon, pts.lat()[q], pts.lon()[q]);
                        dist[i] = d;
                        if (d > radius) continue;
                        ok[i] = p.lineOfSight() == MotorParams.LosMode.TEAM
                                ? LineOfSight.team(terrain, glat, glon, cands.height()[c],
                                pts.lat()[q], pts.lon()[q], pts.height()[q], p.teamSamples(), p.obstructionToleranceM())
                                : LineOfSight.profile(terrain, glat, glon, cz[c], pts.lat()[q], pts.lon()[q], pz[q], d,
                                p.losStepM(), p.obstructionToleranceM(), p.earthCurvature(), p.kFactor(),
                                p.fresnelFraction(), p.frequencyMhz());
                    }
                }
                int[] sel = new int[n];
                int m = 0;
                for (int i = 0; i < n; i++) {
                    if (ok[i] && (!checkBudget || Radio.fsplDb(dist[i], p.frequencyMhz()) <= budget)) {
                        sel[m++] = near[i];
                    }
                }
                int[] col = Arrays.copyOf(sel, m);
                Arrays.sort(col);
                columns[c] = col;
                int k = done.incrementAndGet();
                if (k % logEvery == 0) log.info("Visada: {}/{} candidatos", k, nc);
            })).get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Cálculo de visada interrompido.", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Falha no cálculo de visada: " + e.getCause().getMessage(), e.getCause());
        } finally {
            pool.shutdownNow();
        }
        return CoverageMatrix.fromColumns(np, columns);
    }

    /** Grade uniforme para achar os pontos a até {@code r} metros de um candidato. */
    static final class PointGrid {
        private final double[] px;
        private final double[] py;
        private final double minX;
        private final double minY;
        private final double cell;
        private final int nx;
        private final int ny;
        private final int[] start;
        private final int[] items;

        PointGrid(double[] px, double[] py, double radius) {
            this.px = px;
            this.py = py;
            int n = px.length;
            double mnx = Double.POSITIVE_INFINITY, mny = Double.POSITIVE_INFINITY;
            double mxx = Double.NEGATIVE_INFINITY, mxy = Double.NEGATIVE_INFINITY;
            for (int i = 0; i < n; i++) {
                mnx = Math.min(mnx, px[i]);
                mny = Math.min(mny, py[i]);
                mxx = Math.max(mxx, px[i]);
                mxy = Math.max(mxy, py[i]);
            }
            if (n == 0) {
                mnx = mny = mxx = mxy = 0;
            }
            double extent = Math.max(mxx - mnx, mxy - mny);
            double cs = Math.max(Math.max(radius / 2, 1.0), extent / 1500);
            this.minX = mnx;
            this.minY = mny;
            this.cell = cs;
            this.nx = (int) Math.floor((mxx - mnx) / cs) + 1;
            this.ny = (int) Math.floor((mxy - mny) / cs) + 1;
            int[] count = new int[nx * ny + 1];
            int[] cellOf = new int[n];
            for (int i = 0; i < n; i++) {
                cellOf[i] = cellIndex(px[i], py[i]);
                count[cellOf[i] + 1]++;
            }
            for (int k = 0; k < nx * ny; k++) count[k + 1] += count[k];
            this.start = count.clone();
            int[] next = count;
            this.items = new int[n];
            for (int i = 0; i < n; i++) items[next[cellOf[i]]++] = i;
        }

        private int cellIndex(double x, double y) {
            int gx = Math.min(nx - 1, Math.max(0, (int) Math.floor((x - minX) / cell)));
            int gy = Math.min(ny - 1, Math.max(0, (int) Math.floor((y - minY) / cell)));
            return gx * ny + gy;
        }

        int[] within(double x, double y, double r) {
            int gx0 = Math.max(0, (int) Math.floor((x - r - minX) / cell));
            int gx1 = Math.min(nx - 1, (int) Math.floor((x + r - minX) / cell));
            int gy0 = Math.max(0, (int) Math.floor((y - r - minY) / cell));
            int gy1 = Math.min(ny - 1, (int) Math.floor((y + r - minY) / cell));
            if (gx0 > gx1 || gy0 > gy1) return new int[0];
            int[] out = new int[16];
            int m = 0;
            double r2 = r * r;
            for (int gx = gx0; gx <= gx1; gx++) {
                for (int gy = gy0; gy <= gy1; gy++) {
                    int k = gx * ny + gy;
                    for (int s = start[k]; s < start[k + 1]; s++) {
                        int i = items[s];
                        double dx = px[i] - x;
                        double dy = py[i] - y;
                        if (dx * dx + dy * dy <= r2) {
                            if (m == out.length) out = Arrays.copyOf(out, m * 2);
                            out[m++] = i;
                        }
                    }
                }
            }
            return Arrays.copyOf(out, m);
        }
    }
}
