
package com.tecsys.domain.decision;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ProjectCoverageServiceTest {

    private final ObjectMapper mapper = new ObjectMapper();

    // Salva o resultado usando um repositório simulado
    // e devolve exatamente o summary JSON enviado à persistência.
    private String gravarSummary(String summaryJson) throws Exception {

        ProjectCoverageRepository repository =
                mock(ProjectCoverageRepository.class);

        ProjectCoverageService service =
                new ProjectCoverageService(repository, mapper);

        DecisionSummaryResponseDto summary =
                mapper.readValue(
                        summaryJson,
                        DecisionSummaryResponseDto.class
                );

        DecisionResultResponseDto response =
                new DecisionResultResponseDto(
                        summary,
                        List.of(),
                        List.of(),
                        List.of()
                );

        service.saveCoverage(77L, response);

        ArgumentCaptor<String> captor =
                ArgumentCaptor.forClass(String.class);

        verify(repository).upsertCoverage(
                eq(77L),
                captor.capture(),
                anyString(),
                anyString()
        );

        return captor.getValue();
    }

    @Test
    void deveEnviarNovosParametrosParaPersistencia()
            throws Exception {

        String entrada = """
                {
                    "total_points": 0,
                    "covered_points": 0,
                    "selected_gateways": 0,
                    "profile": "tecsys",
                    "gateway_range_m": 4000,
                    "range_criterion": "fixed_range",
                    "gateway_height_m": 6.0,
                    "sensor_height_m": 5.0,
                    "bdgd_heights": false,
                    "elevation_used": true,
                    "elevation_source": "COP30",
                    "los_mode": "RAYS",
                    "los_step_m": 30.0,
                    "calculation_time_seconds": 2.5
                }
                """;

        String gravado = gravarSummary(entrada);

        var json = mapper.readTree(gravado);

        assertEquals("tecsys", json.get("profile").asText());
        assertEquals(4000, json.get("gateway_range_m").asInt());

        assertEquals(
                "fixed_range",
                json.get("range_criterion").asText()
        );

        assertEquals(
                6.0,
                json.get("gateway_height_m").asDouble()
        );

        assertEquals(
                5.0,
                json.get("sensor_height_m").asDouble()
        );

        assertTrue(json.get("elevation_used").asBoolean());

        assertEquals(
                "COP30",
                json.get("elevation_source").asText()
        );

        assertEquals("RAYS", json.get("los_mode").asText());

        assertEquals(
                30.0,
                json.get("los_step_m").asDouble()
        );

        assertEquals(
                2.5,
                json.get("calculation_time_seconds").asDouble()
        );
    }

    @Test
    void deveAceitarSummarySemCamposNovos()
            throws Exception {

        String entrada = """
                {
                    "total_points": 0,
                    "covered_points": 0,
                    "selected_gateways": 0,
                    "gateway_range_m": 4000
                }
                """;

        String gravado = gravarSummary(entrada);

        var json = mapper.readTree(gravado);

        assertEquals(4000, json.get("gateway_range_m").asInt());

        assertFalse(json.has("elevation_used"));
        assertFalse(json.has("elevation_source"));
        assertFalse(json.has("calculation_time_seconds"));
    }
}
