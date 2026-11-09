package com.tecsys.domain.project.dto;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.tecsys.domain.project.ProjectStatus;
import java.time.Instant;

public record ProjectResponseDto(
        Long id,
        String name,
        @JsonProperty("dist_code") String distCode,
        ProjectStatus status,

        @JsonProperty("created_by_id") Long createdById,
        @JsonProperty("created_by_name") String createdByName,

        @JsonProperty("created_at")
        @JsonFormat(pattern = "dd/MM/yyyy HH:mm:ss", timezone = "America/Sao_Paulo")
        Instant createdAt,

        boolean active,

        // municípios (IBGE) do último cálculo do projeto, para o card mostrar as cidades (#TG-148)
        @JsonProperty("mun_codes") List<String> munCodes
) {
    /** mun_codes de um filter_params salvo em project_history (vazio se não houver). */
    public static List<String> munCodesDe(JsonNode filterParams) {
        if (filterParams == null || !filterParams.path("mun_codes").isArray()) {
            return List.of();
        }
        List<String> codigos = new ArrayList<>();
        filterParams.path("mun_codes").forEach(n -> {
            String c = n.asText("").trim();
            if (!c.isEmpty()) codigos.add(c);
        });
        return List.copyOf(codigos);
    }
}