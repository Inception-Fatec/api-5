package com.tecsys.domain.gateway.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record GatewayProfileRequestDto(
        @NotBlank(message = "O nome é obrigatório")
        String name,

        @NotNull(message = "A frequência é obrigatória")
        @Positive(message = "A frequência deve ser maior que 0")
        Double frequencyMhz,

        @NotNull(message = "A potência Tx é obrigatória")
        Double txPowerDbm,

        @NotNull(message = "O ganho da antena é obrigatório")
        Double antennaGainDbi,

        @NotNull(message = "A sensibilidade Rx é obrigatória")
        @Max(value = 0, message = "A sensibilidade Rx deve ser <= 0")
        Double rxSensitivityDbm,

        @NotNull(message = "A altura da antena é obrigatória")
        @Positive(message = "A altura da antena deve ser maior que 0")
        Double antennaHeightM,

        @NotNull(message = "A capacidade máxima de dispositivos é obrigatória")
        @Positive(message = "A capacidade deve ser maior que 0")
        Integer maxDevices
) {}