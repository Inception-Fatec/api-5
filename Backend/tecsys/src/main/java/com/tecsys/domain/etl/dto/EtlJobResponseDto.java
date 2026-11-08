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
        Long fileSizeBytes,
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
        return montar(job, job.getLogTail());
    }

    /** Igual ao fromEntity, sem o log (usado na listagem do histórico). */
    public static EtlJobResponseDto semLog(EtlJob job) {
        return montar(job, null);
    }

    private static EtlJobResponseDto montar(EtlJob job, String logTail) {
        return new EtlJobResponseDto(
                job.getId(),
                job.getStatus().name(),
                job.getOriginalFilename(),
                job.getFileSizeBytes(),
                Arrays.asList(job.getMunicipios().split(",")),
                parse(job.getSummaryJson()),
                job.getErrorMessage(),
                logTail,
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