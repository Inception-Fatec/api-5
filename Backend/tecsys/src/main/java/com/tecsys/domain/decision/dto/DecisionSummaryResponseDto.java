package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record DecisionSummaryResponseDto(

        @JsonProperty("total_points")
        int totalPoints,

        @JsonProperty("total_candidates")
        int totalCandidates,

        @JsonProperty("selected_gateways")
        int selectedGateways,

        @JsonProperty("covered_points")
        int coveredPoints,

        @JsonProperty("uncovered_points")
        int uncoveredPoints,

        @JsonProperty("coverage_percentage")
        double coveragePercentage,

        @JsonProperty("gateway_range_m")
        int gatewayRangeMeters

) {
}