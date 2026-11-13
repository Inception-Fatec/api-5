package com.tecsys.domain.etl.dto;

/** Ponto gravado por uma importação de CSV (detalhes do histórico de cargas). */
public record ExternalPointResponseDto(
        String id,
        String papel,
        String descricao,
        double latitude,
        double longitude
) {
}
