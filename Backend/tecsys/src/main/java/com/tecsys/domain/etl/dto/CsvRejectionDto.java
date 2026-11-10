package com.tecsys.domain.etl.dto;

public record CsvRejectionDto(
        int linha,
        String id,
        String motivo
) {
}