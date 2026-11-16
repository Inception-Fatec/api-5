package com.tecsys.domain.report.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;
import com.tecsys.domain.project.Project;
import com.tecsys.domain.project.dto.ProjectHistoryResponseDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.report.ProjectCoverage;

import java.time.Instant;
import java.util.List;

/**
 * Um cenário (projeto com resultado calculado) na comparação lado a lado (#75).
 * Os campos de cobertura têm os mesmos nomes e formatos de ProjectCoverageResponseDto.
 */
public record ProjectComparisonItemDto(
        @JsonProperty("project_id") Long projectId,
        String name,
        @JsonProperty("dist_code") String distCode,

        // municípios (IBGE) do cálculo, extraídos do filter_params (mesmo campo de ProjectResponseDto)
        @JsonProperty("mun_codes") List<String> munCodes,

        // perfil de gateway usado no cálculo; null se o filter_params não trouxer
        @JsonProperty("gateway_profile") String gatewayProfile,

        JsonNode summary,
        JsonNode gateways,
        JsonNode points,

        @JsonProperty("calculated_at")
        @JsonFormat(pattern = "dd/MM/yyyy HH:mm:ss", timezone = "America/Sao_Paulo")
        Instant calculatedAt,

        // parâmetros usados no cálculo (último project_history); null se não houver histórico
        @JsonProperty("filter_params") JsonNode filterParams
) {
    public static ProjectComparisonItemDto of(Project project, ProjectCoverage coverage, JsonNode filterParams) {
        return new ProjectComparisonItemDto(
                project.getId(),
                project.getName(),
                project.getDistCode(),
                ProjectResponseDto.munCodesDe(filterParams),
                ProjectHistoryResponseDto.perfilDe(filterParams),
                coverage.getSummary(),
                coverage.getGateways(),
                coverage.getPoints(),
                coverage.getCalculatedAt(),
                filterParams
        );
    }
}