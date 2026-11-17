package com.tecsys.domain.gateway.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record GatewayProfileResponseDto(
        Long id,
        String name,
        Double frequencyMhz,
        Double txPowerDbm,
        Double antennaGainDbi,
        Double rxSensitivityDbm,
        Double antennaHeightM,
        Double sensorHeightM,
        Double extraLossDb,
        Integer maxDevices,
        boolean active,
        @JsonProperty("isDefault") boolean padrao
) {}