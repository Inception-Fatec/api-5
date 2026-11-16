package com.tecsys.domain.gateway.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

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

        // Opcional: sem valor, usa 5 m (altura de referência da Tecsys) (#TG-150)
        @Positive(message = "A altura do sensor deve ser maior que 0")
        Double sensorHeightM,

        // Opcional: perda de vegetação/construções em dB; sem valor, 0 (espaço livre) (#TG-150)
        @PositiveOrZero(message = "A perda adicional deve ser maior ou igual a 0")
        Double extraLossDb,

        @NotNull(message = "A capacidade máxima de dispositivos é obrigatória")
        @Positive(message = "A capacidade deve ser maior que 0")
        Integer maxDevices
) {
    /** Altura do sensor quando o cadastro não informa (referência Tecsys). */
    public static final double ALTURA_SENSOR_PADRAO_M = 5.0;

    public double extraLossDbOuZero() {
        return extraLossDb != null ? extraLossDb : 0.0;
    }

    public double sensorHeightMOuPadrao() {
        return sensorHeightM != null ? sensorHeightM : ALTURA_SENSOR_PADRAO_M;
    }
}
