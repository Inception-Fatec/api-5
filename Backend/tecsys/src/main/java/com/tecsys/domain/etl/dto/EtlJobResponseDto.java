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
        String stage,
        JsonNode inspecao,
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
                Arrays.stream(job.getMunicipios().split(",")).filter(m -> !m.isBlank()).toList(),
                semIdsImportados(parse(job.getSummaryJson())),
                job.getErrorMessage(),
                logTail,
                job.getStage(),
                // Distribuidora/municípios da .gdb só interessam enquanto aguarda a escolha.
                job.getStatus() == com.tecsys.domain.etl.EtlJobStatus.AWAITING_SELECTION
                        ? parse(job.getInspectionJson()) : null,
                job.getCreatedAt(),
                job.getStartedAt(),
                job.getFinishedAt()
        );
    }

    /**
     * Importação de CSV (#TG-90): os ids gravados ficam no summary só para
     * GET /etl/jobs/{id}/pontos; a listagem não precisa deles.
     */
    private static JsonNode semIdsImportados(JsonNode summary) {
        if (summary instanceof com.fasterxml.jackson.databind.node.ObjectNode o) {
            o.remove(com.tecsys.domain.etl.ExternalPointsImportService.CHAVE_IMPORTADOS);
        }
        return summary;
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