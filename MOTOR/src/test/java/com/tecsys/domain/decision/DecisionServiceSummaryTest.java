
package com.tecsys.domain.decision;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import com.tecsys.domain.decision.engine.MotorEngine;
import com.tecsys.domain.decision.engine.MotorParams;
import com.tecsys.domain.decision.engine.MotorResult;
import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import com.tecsys.domain.decision.terrain.FlatTerrain;
import com.tecsys.domain.decision.terrain.GridTerrain;
import com.tecsys.domain.decision.terrain.Terrain;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class DecisionServiceSummaryTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private MotorResult calcular(
            MotorParams params,
            Terrain terrain) {

        var pontos = List.of(
                new CoveragePoint(
                        "p1",
                        VoltageLevel.BAIXO,
                        "3549904",
                        "Centro",
                        "S1",
                        "C1",
                        -23.0,
                        -45.0,
                        1
                )
        );

        var candidatos = List.of(
                new GatewayCandidate(
                        "g1",
                        CandidateType.UNTRMT,
                        "PT",
                        "S1",
                        "3549904",
                        "C1",
                        -23.0,
                        -45.0,
                        true
                )
        );

        return MotorEngine.compute(
                pontos,
                candidatos,
                params,
                1000.0,
                terrain,
                1,
                new MotorEngine.Timer()
        );
    }

    @Test
    void deveRegistrarTerrenoPlanoEParametrosTeam() {

        var params = MotorParams.profile("tecsys")
                .toBuilder()
                .fixedRangeM(1000.0)
                .useTerrain(false)
                .lineOfSight(MotorParams.LosMode.TEAM)
                .teamSamples(5)
                .exactSeconds(0)
                .localSearch(false)
                .build();

        var resultado = calcular(
                params,
                new FlatTerrain()
        );

        var resposta = DecisionService.toResponse(
                resultado,
                1.75
        );

        var summary = mapper.valueToTree(
                resposta.summary()
        );

        assertFalse(summary.get("elevation_used").asBoolean());

        assertEquals(
                "plano",
                summary.get("elevation_source").asText()
        );

        assertEquals(
                "fixed_range",
                summary.get("range_criterion").asText()
        );

        assertEquals(
                "TEAM",
                summary.get("los_mode").asText()
        );

        assertEquals(
                5,
                summary.get("los_samples").asInt()
        );

        assertEquals(
                1.75,
                summary.get("calculation_time_seconds").asDouble(),
                0.001
        );
    }

    @Test
    void deveRegistrarRelevoCop30EParametrosRays() {

        var params = MotorParams.profile("tecsys")
                .toBuilder()
                .fixedRangeM(1000.0)
                .useTerrain(true)
                .lineOfSight(MotorParams.LosMode.RAYS)
                .exactSeconds(0)
                .localSearch(false)
                .build();

        // Terreno sintético identificado como Copernicus.
        // Não realiza download nem consulta serviços externos.
        var terreno = new GridTerrain(
                new float[]{10, 10, 10, 10},
                2,
                2,
                -45.0,
                -23.0,
                0.001,
                0.001,
                "Copernicus GLO-30:teste"
        );

        var resultado = calcular(params, terreno);

        var resposta = DecisionService.toResponse(
                resultado,
                2.5
        );

        var summary = mapper.valueToTree(
                resposta.summary()
        );

        assertTrue(summary.get("elevation_used").asBoolean());

        assertEquals(
                "COP30",
                summary.get("elevation_source").asText()
        );

        assertEquals(
                "RAYS",
                summary.get("los_mode").asText()
        );

        assertEquals(
                30.0,
                summary.get("los_step_m").asDouble(),
                0.001
        );

        assertFalse(summary.has("los_samples"));

        assertEquals(
                6.0,
                summary.get("gateway_height_m").asDouble(),
                0.001
        );

        assertEquals(
                5.0,
                summary.get("sensor_height_m").asDouble(),
                0.001
        );
    }

    @Test
    void deveAceitarSummaryAntigoSemNovosCampos()
            throws Exception {

        String jsonAntigo = """
                {
                    "total_points": 10,
                    "selected_gateways": 2,
                    "gateway_range_m": 4000
                }
                """;

        var summary = mapper.readValue(
                jsonAntigo,
                DecisionSummaryResponseDto.class
        );

        assertEquals(10, summary.totalPoints());
        assertEquals(2, summary.selectedGateways());
        assertEquals(4000, summary.gatewayRangeMeters());

        // Campos adicionados pela TG-77 eram inexistentes.
        assertNull(summary.elevationUsed());
        assertNull(summary.elevationSource());
        assertNull(summary.calculationTimeSeconds());
    }
}
