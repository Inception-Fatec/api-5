package com.tecsys.domain.report.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;
import com.tecsys.domain.report.ProjectCoverage;

import java.time.Instant;

public record ProjectCoverageResponseDto(
        @JsonProperty("project_id") Long projectId,
        JsonNode summary,
        JsonNode gateways,
        JsonNode points,

        @JsonProperty("calculated_at")
        @JsonFormat(pattern = "dd/MM/yyyy HH:mm:ss", timezone = "America/Sao_Paulo")
        Instant calculatedAt
) {
    public static ProjectCoverageResponseDto fromEntity(ProjectCoverage entity) {
        return new ProjectCoverageResponseDto(
                entity.getProjectId(),
                entity.getSummary(),
                entity.getGateways(),
                entity.getPoints(),
                entity.getCalculatedAt()
        );
    }
}