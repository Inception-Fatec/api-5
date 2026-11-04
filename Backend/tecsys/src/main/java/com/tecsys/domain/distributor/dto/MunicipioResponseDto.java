package com.tecsys.domain.distributor.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record MunicipioResponseDto(
        @JsonProperty("ibge_code") String ibgeCode,
        Double latitude,
        Double longitude
) {}