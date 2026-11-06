package com.tecsys.domain.point.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * total_points = só consumidores (os pontos que o motor cobre);
 * total_candidates = transformadores (onde o motor pode pôr gateway);
 * total_network = trechos de rede e subestações (só desenho).
 */
public record PointFilterResponseDto(
        @JsonProperty("total_points") Long totalPoints,
        @JsonProperty("total_candidates") Long totalCandidates,
        @JsonProperty("total_network") Long totalNetwork,
        JsonNode features
) {
    public PointFilterResponseDto(Long totalPoints, JsonNode features) {
        this(totalPoints, 0L, 0L, features);
    }
}
