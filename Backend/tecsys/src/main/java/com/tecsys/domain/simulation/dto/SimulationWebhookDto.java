package com.tecsys.domain.simulation.dto;

import com.tecsys.domain.project.ProjectStatus;
import jakarta.validation.constraints.NotNull;

public record SimulationWebhookDto(
        @NotNull(message = "O status final é obrigatório.")
        ProjectStatus status
) {}