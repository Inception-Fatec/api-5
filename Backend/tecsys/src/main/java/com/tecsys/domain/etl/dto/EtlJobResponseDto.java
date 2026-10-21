package com.tecsys.domain.etl.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.etl.EtlJob;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

public record EtlJobResponseDto(
        Long id,
        String status,
        String originalFilename,
        List<String> municipios,
        JsonNode summary,
        String errorMessage,
        String logTail,
        Instant createdAt,
        Instant startedAt,
        Instant finishedAt
) {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static EtlJobResponseDto fromEntity(EtlJob job) {
        return new EtlJobResponseDto(
                job.getId(),
                job.getStatus().name(),
                job.getOriginalFilename(),
                Arrays.asList(job.getMunicipios().split(",")),
                parse(job.getSummaryJson()),
                job.getErrorMessage(),
                job.getLogTail(),
                job.getCreatedAt(),
                job.getStartedAt(),
                job.getFinishedAt()
        );
    }

    private static JsonNode parse(String json) {
        if (json == null || json.isBlank()) {
            return null;
        }
        try {
            return MAPPER.readTree(json);
        } catch (Exception e) {
            return null;
        }
    }
}