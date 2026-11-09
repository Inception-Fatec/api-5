package com.tecsys.domain.project.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotNull;

/**
 * Corpo do POST /projects/{id}/recalculate (#TG-84): os mesmos campos do
 * /simulation/run. Sem {@code geometry}, a nova versão mantém a área da anterior.
 */
public record ProjectRecalculateRequestDto(
        @JsonProperty("geometry")
        String geometry,

        @NotNull(message = "Os filtros (filter_params) são obrigatórios para recalcular.")
        @JsonProperty("filter_params")
        JsonNode filterParams
) {}
