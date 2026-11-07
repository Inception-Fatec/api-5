package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.DecisionRepository;
import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoverageAssignment;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.SelectedGateway;
import com.tecsys.domain.decision.model.VoltageLevel;
import com.tecsys.domain.decision.terrain.DemService;
import com.tecsys.domain.decision.terrain.FlatTerrain;
import com.tecsys.domain.decision.terrain.Terrain;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Orquestra o cálculo: dados → relevo → matriz de cobertura → otimização → resultado.
 *
 * <p>Pontos e candidatos no mesmo lugar e com a mesma altura viram um único "local", porque têm
 * a mesma cobertura (em SJC, 31 mil pontos viram 18,7 mil locais). A otimização trabalha sobre os
 * locais, com o peso de cada um igual ao nº de pontos que ele representa.
 */
@Component
public class MotorEngine {

    private static final Logger log = LoggerFactory.getLogger(MotorEngine.class);
    /** Acima disso o solver exato não é tentado: LNS + lagrangiano. */
    private static final long EXACT_MAX_PAIRS = 4_000_000L;

    private final DecisionRepository repository;
    private final DemService demService;
    private final MotorProperties properties;

    public MotorEngine(DecisionRepository repository, DemService demService, MotorProperties properties) {
        this.repository = repository;
        this.demService = demService;
        this.properties = properties;
    }

    public MotorParams params() {
        return properties.toParams();
    }

    public MotorResult run(DecisionCriteria criteria, MotorParams p) throws IOException {
        Timer timer = new Timer();
        List<CoveragePoint> points = repository.findCoveragePoints(criteria, p.bairroLikeMap());
        timer.mark("pontos");
        double radius = searchRadius(p, points);
        List<GatewayCandidate> cands = points.isEmpty() ? List.of()
                : repository.findGatewayCandidates(criteria, p.neighborCandidates(), radius, p.bairroLikeMap());
        timer.mark("candidatos");
        if (points.isEmpty() || cands.isEmpty()) {
            return compute(points, cands, p, radius, new FlatTerrain(), properties.effectiveThreads(), timer);
        }

        Terrain terrain;
        if (p.useTerrain()) {
            double margin = p.lineOfSight() == MotorParams.LosMode.RAYS ? radius / 111_000.0 + 0.01 : 0.04;
            double s = Double.POSITIVE_INFINITY, n = Double.NEGATIVE_INFINITY;
            double w = Double.POSITIVE_INFINITY, e = Double.NEGATIVE_INFINITY;
            for (CoveragePoint pt : points) {
                s = Math.min(s, pt.latitude()); n = Math.max(n, pt.latitude());
                w = Math.min(w, pt.longitude()); e = Math.max(e, pt.longitude());
            }
            for (GatewayCandidate c : cands) {
                s = Math.min(s, c.latitude()); n = Math.max(n, c.latitude());
                w = Math.min(w, c.longitude()); e = Math.max(e, c.longitude());
            }
            DemService.Loaded loaded = demService.load(s - margin, n + margin, w - margin, e + margin);
            terrain = loaded.terrain();
            log.info("Relevo: {} ({} tile(s), {}, {} s, cotas {}..{} m)", terrain.source(), loaded.info().tiles(),
                    loaded.info().fromCache() ? "cache/mirror" : "download", round(loaded.info().downloadSeconds(), 1),
                    round(terrain.minElevation(), 0), round(terrain.maxElevation(), 0));
        } else {
            log.warn("Relevo desligado (use-terrain=false): cálculo sobre terreno plano.");
            terrain = new FlatTerrain();
        }
        timer.mark("relevo");
        return compute(points, cands, p, radius, terrain, properties.effectiveThreads(), timer);
    }

    // ------------------------------------------------------------------ cálculo

    public static double searchRadius(MotorParams p, List<CoveragePoint> points) {
        double hp = p.sensorHeightM();
        if (p.bdgdHeights() && !points.isEmpty()) {
            hp = points.stream().mapToDouble(pt -> pointHeight(p, pt)).max().orElse(hp);
        }
        double hg = p.bdgdHeights() ? 15.0 : p.gatewayHeightM();
        return Radio.searchRangeM(p, hg, hp);
    }

    /** Altura da antena do gateway: por tipo de estrutura da BDGD, ou a do perfil. */
    public static double gatewayHeight(MotorParams p, GatewayCandidate c) {
        if (!p.bdgdHeights()) return p.gatewayHeightM();
        if (c.type() == CandidateType.UNTRAT || c.type() == CandidateType.SUB) return 15.0; // mastro de telecom
        String posto = c.posto() == null ? "" : c.posto().trim();
        if (posto.equalsIgnoreCase("CAB") || posto.equalsIgnoreCase("SUB")) return 3.5;    // cabine / pedestal
        return 10.5;                                                                         // poste
    }

    /** Altura da antena do ponto: por nível de tensão, ou a do perfil. */
    public static double pointHeight(MotorParams p, CoveragePoint pt) {
        if (!p.bdgdHeights()) return p.sensorHeightM();
        if (pt.level() == VoltageLevel.ALTO) return 10.0;
        if (pt.level() == VoltageLevel.MEDIO) return 6.0;
        return 3.0;
    }

    public static MotorResult compute(List<CoveragePoint> points, List<GatewayCandidate> cands, MotorParams p,
                                      double radius, Terrain terrain, int threads, Timer timer) {
        int total = points.size();
        int outside = (int) cands.stream().filter(c -> !c.insideFilters()).count();
        if (total == 0 || cands.isEmpty()) {
            List<CoveragePoint> uncovered = cands.isEmpty() ? points : List.of();
            return new MotorResult(p, radius, total, cands.size(), outside, 0, 0, 0, 0,
                    List.of(), List.of(), uncovered, 0.0, 0, 0, null, "nenhum",
                    total == 0 ? "sem pontos" : "sem candidatos", terrain.source(), timer.marks);
        }

        // --- agrupamento em locais únicos
        double[] hp = new double[total];
        double[] plat = new double[total];
        double[] plon = new double[total];
        for (int i = 0; i < total; i++) {
            CoveragePoint pt = points.get(i);
            hp[i] = pointHeight(p, pt);
            plat[i] = pt.latitude();
            plon[i] = pt.longitude();
        }
        double[] hc = new double[cands.size()];
        double[] clat = new double[cands.size()];
        double[] clon = new double[cands.size()];
        for (int i = 0; i < cands.size(); i++) {
            GatewayCandidate c = cands.get(i);
            hc[i] = gatewayHeight(p, c);
            clat[i] = c.latitude();
            clon[i] = c.longitude();
        }
        Groups gp = Groups.of(plat, plon, hp);
        Groups gc = Groups.of(clat, clon, hc);
        long[] w = new long[gp.count()];
        for (int g : gp.groupOf) w[g]++;
        timer.mark("agrupamento");

        // --- matriz de cobertura
        double latSum = 0, lonSum = 0;
        for (int i = 0; i < total; i++) { latSum += plat[i]; lonSum += plon[i]; }
        for (int i = 0; i < cands.size(); i++) { latSum += clat[i]; lonSum += clon[i]; }
        int all = total + cands.size();
        Geo.LocalProjection proj = new Geo.LocalProjection(latSum / all, lonSum / all);
        CoverageMatrix a = CoverageBuilder.build(p, terrain, proj,
                gp.sites(plat, plon, hp), gc.sites(clat, clon, hc), radius, threads);
        timer.mark("visada");

        // --- otimização
        long coverable = 0;
        int[] rowPtr = a.rowPtr();
        for (int r = 0; r < a.nRows; r++) if (rowPtr[r + 1] > rowPtr[r]) coverable += w[r];
        int[] sel = SetCover.greedy(a, w).cols();
        int nGreedy = sel.length;
        timer.mark("guloso");
        sel = SetCover.removeRedundant(a, sel);
        double[] cx = new double[gc.count()];
        double[] cy = new double[gc.count()];
        for (int j = 0; j < gc.count(); j++) {
            cx[j] = proj.x(clon[gc.rep[j]]);
            cy[j] = proj.y(clat[gc.rep[j]]);
        }
        if (p.localSearch()) {
            sel = SetCover.localSearch2for1(a, sel, cx, cy, radius, 60.0);
        }
        sel = SetCover.removeRedundant(a, sel);
        timer.mark("busca_local");

        int lb = SetCover.packingBound(a);
        String method = "guloso + busca local";
        String status = "heurístico";
        if (p.exactSeconds() > 0) {
            if (a.nnz() <= EXACT_MAX_PAIRS) {
                SetCover.Exact ex = SetCover.exact(a, p.exactSeconds(), EXACT_MAX_PAIRS, threads);
                method = "exato (HiGHS)";
                status = ex.status();
                if (ex.bound() != null) lb = Math.max(lb, ex.bound());
                if (ex.cols() != null && ex.cols().length < sel.length) sel = ex.cols();
            } else {
                SetCover.LnsResult lns = SetCover.lns(a, sel, cx, cy, 0.6 * p.exactSeconds(), 7, 3, 8, 2.0);
                sel = SetCover.removeRedundant(a, lns.cols());
                lb = Math.max(lb, SetCover.lagrangianBound(a, sel.length, 0.4 * p.exactSeconds(), 3000));
                method = "LNS + lagrangiano";
                status = lb == sel.length ? "ótimo" : "limite inferior";
                log.info("LNS: {} tentativas, {} melhorias em {} s", lns.stats().attempts(),
                        lns.stats().improvements(), round(lns.stats().seconds(), 1));
            }
        }
        timer.mark("exato");

        // --- ordem final (curva de cobertura acumulada) e atribuição
        SetCover.Greedy ordered = SetCover.orderSelection(a, sel, w);
        int[] firstGw = new int[a.nRows];
        Arrays.fill(firstGw, -1);
        List<SelectedGateway> gateways = new ArrayList<>();
        long cumulative = 0;
        for (int i = 0; i < ordered.cols().length; i++) {
            int col = ordered.cols()[i];
            for (int k = a.colPtr[col]; k < a.colPtr[col + 1]; k++) {
                if (firstGw[a.rows[k]] < 0) firstGw[a.rows[k]] = i;
            }
            cumulative += ordered.gains()[i];
            gateways.add(new SelectedGateway(i + 1, cands.get(gc.rep[col]), (int) ordered.gains()[i],
                    (int) cumulative, round(100.0 * cumulative / total, 2)));
        }
        List<CoverageAssignment> covered = new ArrayList<>();
        List<CoveragePoint> uncovered = new ArrayList<>();
        for (int i = 0; i < total; i++) {
            int g = firstGw[gp.groupOf[i]];
            if (g >= 0) {
                covered.add(new CoverageAssignment(points.get(i), gateways.get(g).candidate(), g + 1));
            } else {
                uncovered.add(points.get(i));
            }
        }
        Double gap = lb > 0 ? round(100.0 * (gateways.size() - lb) / lb, 2) : null;
        timer.mark("resultado");

        return new MotorResult(p, radius, total, cands.size(), outside, gp.count(), gc.count(), a.nnz(),
                (int) coverable, gateways, covered, uncovered, round(100.0 * covered.size() / total, 2),
                nGreedy, lb, gap, method, status, terrain.source(), timer.marks);
    }

    static double round(double v, int places) {
        double f = Math.pow(10, places);
        return Math.round(v * f) / f;
    }

    /**
     * Itens no mesmo lugar (1e-6°) e com a mesma altura (cm) formam um grupo. Os grupos seguem a
     * ordem das chaves (lat, lon, altura); o representante é o primeiro item do grupo.
     */
    record Groups(int[] groupOf, int[] rep) {
        int count() {
            return rep.length;
        }

        CoverageBuilder.Sites sites(double[] lat, double[] lon, double[] h) {
            double[] la = new double[rep.length], lo = new double[rep.length], hh = new double[rep.length];
            for (int g = 0; g < rep.length; g++) {
                la[g] = lat[rep[g]];
                lo[g] = lon[rep[g]];
                hh[g] = h[rep[g]];
            }
            return new CoverageBuilder.Sites(la, lo, hh);
        }

        static Groups of(double[] lat, double[] lon, double[] h) {
            int n = lat.length;
            long[][] keys = new long[n][];
            for (int i = 0; i < n; i++) {
                keys[i] = new long[]{Math.round(lat[i] * 1e6), Math.round(lon[i] * 1e6), Math.round(h[i] * 100), i};
            }
            Arrays.sort(keys, (x, y) -> {
                for (int k = 0; k < 4; k++) if (x[k] != y[k]) return Long.compare(x[k], y[k]);
                return 0;
            });
            int[] groupOf = new int[n];
            List<Integer> reps = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                boolean same = i > 0 && keys[i][0] == keys[i - 1][0] && keys[i][1] == keys[i - 1][1]
                        && keys[i][2] == keys[i - 1][2];
                if (!same) reps.add((int) keys[i][3]);
                groupOf[(int) keys[i][3]] = reps.size() - 1;
            }
            return new Groups(groupOf, reps.stream().mapToInt(Integer::intValue).toArray());
        }
    }

    /** Marca o tempo de cada etapa (s). */
    public static final class Timer {
        private final long start = System.nanoTime();
        private long last = start;
        final Map<String, Double> marks = new LinkedHashMap<>();

        public void mark(String name) {
            long now = System.nanoTime();
            marks.put(name, round((now - last) / 1e9, 3));
            last = now;
        }

        public double totalSeconds() {
            return round((System.nanoTime() - start) / 1e9, 3);
        }
    }
}
