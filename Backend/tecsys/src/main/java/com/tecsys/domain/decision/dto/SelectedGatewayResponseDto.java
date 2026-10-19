
package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;

public record SelectedGatewayResponseDto(

        int order,

        String id,

        @JsonIgnore
        String type,

        @JsonIgnore
        String posto,

        @JsonIgnore
        String sub,

        double latitude,

        double longitude,

        @JsonProperty("new_points_covered")
        int newPointsCovered,

        @JsonProperty("cumulative_points_covered")
        int cumulativePointsCovered,

        @JsonProperty("cumulative_coverage_percentage")
        double cumulativeCoveragePercentage

) {
}
