package com.tecsys.domain.point.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;

public record PointFilterResponseDto(
        @JsonProperty("total_points") Long totalPoints,
        JsonNode features
) {}