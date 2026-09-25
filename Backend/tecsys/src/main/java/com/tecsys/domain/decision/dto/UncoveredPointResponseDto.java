package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record UncoveredPointResponseDto(

        String id,

        String level,

        double latitude,

        double longitude,

        String bairro,

        @JsonProperty("municipality_code")
        String municipalityCode,

        String sub,

        String conjunto

) {
}