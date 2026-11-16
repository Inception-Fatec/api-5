package com.tecsys.domain.etl.dto;

import java.util.List;

/**
 * Pontos de uma importação: {@code total} conta todos; {@code pontos} traz no
 * máximo {@code limite}, na ordem em que foram gravados.
 */
public record ExternalPointsListResponseDto(
        long total,
        int limite,
        List<ExternalPointResponseDto> pontos
) {
    public ExternalPointsListResponseDto {
        pontos = List.copyOf(pontos);
    }
}
