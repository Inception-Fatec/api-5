package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import com.tecsys.domain.decision.terrain.FlatTerrain;
import com.tecsys.domain.decision.terrain.GridTerrain;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MotorEngineTest {

    private static CoveragePoint point(String id, double lat, double lon) {
        return new CoveragePoint(id, VoltageLevel.BAIXO, "3549904", "Centro", "S1", "C1", lat, lon);
    }

    private static GatewayCandidate cand(String id, double lat, double lon, boolean inside) {
        return new GatewayCandidate(id, CandidateType.UNTRMT, "PT", "S1", "3549904", "C1", lat, lon, inside);
    }

    /** Dois aglomerados de pontos a ~11 km um do outro, um candidato no meio de cada. */
    private static List<CoveragePoint> twoClusters() {
        List<CoveragePoint> pts = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            pts.add(point("a" + i, -23.000 + i * 1e-4, -45.900));
            pts.add(point("b" + i, -23.000 + i * 1e-4, -45.800));
        }
        pts.add(point("dup", -23.000, -45.900)); // mesmo lugar de a0: vira o mesmo local
        return pts;
    }

    @Test
    void escolheUmGatewayPorAglomeradoComAlcanceFixo() {
        MotorParams p = MotorParams.profile("tecsys").toBuilder()
                .fixedRangeM(3000.0).useTerrain(false).exactSeconds(5).build();
        List<CoveragePoint> pts = twoClusters();
        List<GatewayCandidate> cands = List.of(
                cand("ga", -23.001, -45.901, true),
                cand("gb", -23.001, -45.801, false),
                cand("longe", -23.300, -45.500, true));

        MotorResult r = MotorEngine.compute(pts, cands, p, 3000, new FlatTerrain(), 2, new MotorEngine.Timer());

        assertEquals(2, r.gateways().size());
        assertEquals(41, r.totalPoints());
        assertEquals(40, r.uniquePoints());
        assertEquals(41, r.covered().size());
        assertEquals(0, r.uncovered().size());
        assertEquals(100.0, r.coveragePercentage());
        assertEquals(1, r.candidatesOutsideFilters());
        assertEquals(2, r.lowerBound());
        assertEquals(0.0, r.gapPct());
        // a curva acumulada termina nos 41 pontos e o primeiro gateway é o que cobre mais (a + dup)
        assertEquals(41, r.gateways().get(1).cumulativePointsCovered());
        assertEquals("ga", r.gateways().get(0).candidate().id());
        assertEquals(21, r.gateways().get(0).newPointsCovered());
    }

    @Test
    void pontoForaDoAlcanceFicaDescoberto() {
        MotorParams p = MotorParams.profile("tecsys").toBuilder()
                .fixedRangeM(3000.0).useTerrain(false).exactSeconds(0).build();
        List<CoveragePoint> pts = new ArrayList<>(twoClusters());
        pts.add(point("isolado", -23.5, -45.0));
        List<GatewayCandidate> cands = List.of(cand("ga", -23.001, -45.901, true), cand("gb", -23.001, -45.801, true));

        MotorResult r = MotorEngine.compute(pts, cands, p, 3000, new FlatTerrain(), 2, new MotorEngine.Timer());

        assertEquals(1, r.uncovered().size());
        assertEquals("isolado", r.uncovered().get(0).id());
        assertEquals(41, r.coverablePoints());
        assertEquals(r.totalPoints(), r.covered().size() + r.uncovered().size());
    }

    @Test
    void morroEntreGatewayEPontoExigeOutroGateway() {
        // morro de 300 m em lon ≈ −45,95; pontos a leste do morro; um candidato a oeste e outro a leste
        GridTerrain t = Terrains.ridge(300);
        MotorParams p = MotorParams.profile("tecsys").toBuilder().exactSeconds(5).build();
        List<CoveragePoint> pts = new ArrayList<>();
        for (int i = 0; i < 10; i++) pts.add(point("p" + i, -23.05 + i * 1e-3, -45.93));
        List<GatewayCandidate> cands = List.of(
                cand("oeste", -23.05, -45.97, true),
                cand("leste", -23.05, -45.92, true));

        MotorResult r = MotorEngine.compute(pts, cands, p, 4000, t, 2, new MotorEngine.Timer());

        assertEquals(1, r.gateways().size());
        assertEquals("leste", r.gateways().get(0).candidate().id());
        assertEquals(100.0, r.coveragePercentage());
        assertTrue(r.visiblePairs() == 10, "o candidato a oeste não enxerga nenhum ponto: " + r.visiblePairs());
    }
}
