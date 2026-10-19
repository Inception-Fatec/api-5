package com.tecsys.domain.project.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ProjectCreateRequestDto(
        @NotBlank(message = "O nome do projeto é obrigatório.")
        String name,

        @NotBlank(message = "O código da distribuidora (dist) é obrigatório.")
        @Size(max = 10, message = "O código da distribuidora deve ter no máximo 10 caracteres.")
        @JsonProperty("dist_code")
        String distCode
) {}