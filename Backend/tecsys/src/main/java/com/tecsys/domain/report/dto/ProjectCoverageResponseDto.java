package com.tecsys.domain.report.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.tecsys.domain.report.ProjectCoverage;

public record ProjectCoverageResponseDto(
        Long projectId,
        JsonNode summary,
        JsonNode gateways,
        JsonNode points
) {
    public static ProjectCoverageResponseDto fromEntity(ProjectCoverage entity) {
        return new ProjectCoverageResponseDto(
                entity.getProjectId(),
                entity.getSummary(),
                entity.getGateways(),
                entity.getPoints()
        );
    }
}