package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;

import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record ProjectCoveragePayloadDto(
        JsonNode summary,
        @JsonProperty("selected_gateways")
        JsonNode selectedGateways,
        @JsonProperty("covered_points")
        List<PointDto> coveredPoints,
        @JsonProperty("uncovered_points")
        List<PointDto> uncoveredPoints
) {
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record PointDto(
            String id,
            double latitude,
            double longitude
    ) {}
}