package com.tecsys.domain.distributor.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record MunicipioResponseDto(
        @JsonProperty("ibge_code") String ibgeCode,
        Double latitude,
        Double longitude,
        // a cidade tem rede da BDGD / pontos importados por CSV (#TG-151)
        @JsonProperty("tem_rede") boolean temRede,
        @JsonProperty("tem_csv") boolean temCsv
) {}