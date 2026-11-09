package com.tecsys.domain.distributor.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record DistributorResponseDto(
        String dist,
        String nome,
        @JsonProperty("total_sub")
        Long totalSub
) {}