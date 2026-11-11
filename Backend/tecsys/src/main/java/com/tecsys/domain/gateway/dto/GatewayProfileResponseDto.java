package com.tecsys.domain.gateway.dto;

public record GatewayProfileResponseDto(
        Long id,
        String name,
        Double frequencyMhz,
        Double txPowerDbm,
        Double antennaGainDbi,
        Double rxSensitivityDbm,
        Double antennaHeightM,
        Integer maxDevices,
        boolean active
) {}