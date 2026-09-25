package com.tecsys.domain.project.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.tecsys.domain.project.ProjectStatus;
import java.time.Instant;

public record ProjectResponseDto(
        Long id,
        String name,
        @JsonProperty("dist_code") String distCode,
        ProjectStatus status,
        @JsonProperty("created_by_id") Long createdById,
        @JsonProperty("created_at") Instant createdAt
) {}