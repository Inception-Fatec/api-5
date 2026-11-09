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

        // consumidores (peso dos pontos, #TG-144)

        @JsonProperty("new_consumers_covered")

        long newConsumersCovered,

        @JsonProperty("cumulative_consumers_covered")

        long cumulativeConsumersCovered,

        @JsonProperty("cumulative_coverage_percentage")
        double cumulativeCoveragePercentage,

        // altura da antena usada no cálculo (m)
        @JsonProperty("height_m")
        double heightMeters,

        // trafo fora dos filtros do projeto, escolhido por estar ao alcance da área (#TG-138)
        @JsonProperty("outside_filters")
        boolean outsideFilters

) {
}
