package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record CalculateRequestDto(
        @JsonProperty("project_id")
        Long projectId
) {}