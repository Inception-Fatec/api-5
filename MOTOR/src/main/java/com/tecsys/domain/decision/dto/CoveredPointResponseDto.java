package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record CoveredPointResponseDto(

        String id,

        String level,

        double latitude,

        double longitude,

        String bairro,

        @JsonProperty("municipality_code")
        String municipalityCode,

        String sub,

        String conjunto,

        @JsonProperty("covered_by_gateway_id")
        String coveredByGatewayId,

        @JsonProperty("gateway_order")
        int gatewayOrder

) {
}