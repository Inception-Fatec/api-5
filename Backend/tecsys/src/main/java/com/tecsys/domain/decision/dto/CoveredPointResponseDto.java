
package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;

public record CoveredPointResponseDto(

        String id,

        @JsonIgnore
        String level,

        double latitude,

        double longitude,

        @JsonIgnore
        String bairro,

        @JsonIgnore
        @JsonProperty("municipality_code")
        String municipalityCode,

        @JsonIgnore
        String sub,

        @JsonIgnore
        String conjunto,

        @JsonIgnore
        @JsonProperty("covered_by_gateway_id")
        String coveredByGatewayId,

        @JsonIgnore
        @JsonProperty("gateway_order")
        int gatewayOrder

) {
}
