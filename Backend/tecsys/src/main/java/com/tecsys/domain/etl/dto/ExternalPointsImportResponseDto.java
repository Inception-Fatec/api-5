package com.tecsys.domain.etl.dto;

import java.util.List;

public record ExternalPointsImportResponseDto(
        int total,
        int importadas,
        int jaExistentes,
        int rejeitadas,
        List<CsvRejectionDto> rejeicoes
) {
    public ExternalPointsImportResponseDto {
        rejeicoes = List.copyOf(rejeicoes);
    }
}