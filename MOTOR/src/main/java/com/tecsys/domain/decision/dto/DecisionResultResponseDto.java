package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

public record DecisionResultResponseDto(

        DecisionSummaryResponseDto summary,

        @JsonProperty("selected_gateways")
        List<SelectedGatewayResponseDto> selectedGateways,

        @JsonProperty("covered_points")
        List<CoveredPointResponseDto> coveredPoints,

        @JsonProperty("uncovered_points")
        List<UncoveredPointResponseDto> uncoveredPoints

) {
}