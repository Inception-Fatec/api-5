package com.tecsys.domain.decision.service;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class BDGDHeightResolverTest {

    private final BDGDHeightResolver resolver = new BDGDHeightResolver();

    @Test
    void shouldResolveGatewayHeightsAccordingToCandidateType() {
        GatewayCandidate untrat = new GatewayCandidate(
                "1", CandidateType.UNTRAT, null, "sub-1", "mun-1", "conj-1", 0.0, 0.0
        );
        assertEquals(15.0, resolver.resolveGatewayHeight(untrat));

        GatewayCandidate untrmtPoste = new GatewayCandidate(
                "2", CandidateType.UNTRMT, "POSTE", "sub-1", "mun-1", "conj-1", 0.0, 0.0
        );
        assertEquals(10.5, resolver.resolveGatewayHeight(untrmtPoste));

        GatewayCandidate untrmtCabina = new GatewayCandidate(
                "3", CandidateType.UNTRMT, "CAB", "sub-1", "mun-1", "conj-1", 0.0, 0.0
        );
        assertEquals(3.5, resolver.resolveGatewayHeight(untrmtCabina));
    }

    @Test
    void shouldResolvePointHeightsAccordingToVoltageLevel() {
        CoveragePoint alto = new CoveragePoint("1", VoltageLevel.ALTO, "mun-1", "bairro", "sub-1", "conj-1", 0.0, 0.0);
        assertEquals(10.0, resolver.resolvePointHeight(alto));

        CoveragePoint medio = new CoveragePoint("2", VoltageLevel.MEDIO, "mun-1", "bairro", "sub-1", "conj-1", 0.0, 0.0);
        assertEquals(6.0, resolver.resolvePointHeight(medio));

        CoveragePoint baixo = new CoveragePoint("3", VoltageLevel.BAIXO, "mun-1", "bairro", "sub-1", "conj-1", 0.0, 0.0);
        assertEquals(3.0, resolver.resolvePointHeight(baixo));
    }
}

