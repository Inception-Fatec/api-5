package com.tecsys.domain.etl;

public record ExternalPointRow(
        String externalId,
        String papel,
        String descricao,
        double latitude,
        double longitude
) {
}