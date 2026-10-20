package com.tecsys.domain.decision.service;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.when;

class LineOfSightServiceTest {

    private ElevationService elevationService;
    private BDGDHeightResolver heightResolver;
    private LineOfSightService lineOfSightService;

    @BeforeEach
    void setUp() {
        elevationService = Mockito.mock(ElevationService.class);
        heightResolver = new BDGDHeightResolver();
        lineOfSightService = new LineOfSightService(elevationService, heightResolver, 1.5, 5);
    }

    @Test
    void shouldReturnTrueWhenLineOfSightIsUnobstructedWithRaster() {
        GatewayCandidate candidate = new GatewayCandidate(
                "gw-1", CandidateType.UNTRMT, "POSTE", "sub-1", "3549904", "conj-1", -23.18, -45.88
        );
        CoveragePoint point = new CoveragePoint(
                "pt-1", VoltageLevel.BAIXO, "3549904", "Centro", "sub-1", "conj-1", -23.19, -45.89
        );

        AreaElevationRaster raster = (lat, lon) -> 600.0;
        boolean hasLos = lineOfSightService.hasLineOfSight(candidate, point, raster);

        assertTrue(hasLos);
    }

    @Test
    void shouldReturnTrueWhenObstructionIsWithinTolerance() {
        GatewayCandidate candidate = new GatewayCandidate(
                "gw-1", CandidateType.UNTRMT, "POSTE", "sub-1", "3549904", "conj-1", -23.180, -45.880
        );
        CoveragePoint point = new CoveragePoint(
                "pt-1", VoltageLevel.BAIXO, "3549904", "Centro", "sub-1", "conj-1", -23.190, -45.890
        );

        // zStart = 500 + 10.5 = 510.5
        // zEnd = 500 + 3.0 = 503.0
        // No meio (fraction 0.5): radioZ = 506.75
        // Terreno intermediário a 507.5 (+0.75m acima da linha) -> menor que a tolerância de 1.5m (506.75 + 1.5 = 508.25)
        AreaElevationRaster raster = (lat, lon) -> {
            // Apenas no meio do caminho (fraction ~ 0.5: lat ~ -23.185)
            if (lat > -23.186 && lat < -23.184) {
                return 507.5;
            }
            return 500.0;
        };

        boolean hasLos = lineOfSightService.hasLineOfSight(candidate, point, raster);
        assertTrue(hasLos, "Deveria passar com tolerância de 1.5m");
    }

    @Test
    void shouldReturnFalseWhenObstructedBeyondTolerance() {
        GatewayCandidate candidate = new GatewayCandidate(
                "gw-1", CandidateType.UNTRMT, "POSTE", "sub-1", "3549904", "conj-1", -23.180, -45.880
        );
        CoveragePoint point = new CoveragePoint(
                "pt-1", VoltageLevel.BAIXO, "3549904", "Centro", "sub-1", "conj-1", -23.190, -45.890
        );

        // Terreno a 700m (muito além da linha de rádio ~510m e da tolerância de 1.5m)
        AreaElevationRaster raster = (lat, lon) -> {
            if (lat > -23.189 && lat < -23.181) {
                return 700.0;
            }
            return 500.0;
        };

        boolean hasLos = lineOfSightService.hasLineOfSight(candidate, point, raster);

        assertFalse(hasLos);
    }

    @Test
    void shouldReturnTrueWhenLineOfSightIsUnobstructedWithMapCache() {
        GatewayCandidate candidate = new GatewayCandidate(
                "gw-1", CandidateType.UNTRMT, "POSTE", "sub-1", "3549904", "conj-1", -23.18, -45.88
        );
        CoveragePoint point = new CoveragePoint(
                "pt-1", VoltageLevel.BAIXO, "3549904", "Centro", "sub-1", "conj-1", -23.19, -45.89
        );

        when(elevationService.getElevation(anyDouble(), anyDouble(), anyMap()))
                .thenReturn(600.0);

        Map<String, Double> cache = new HashMap<>();
        boolean hasLos = lineOfSightService.hasLineOfSight(candidate, point, cache);

        assertTrue(hasLos);
    }
}
