package com.tecsys.domain.decision.model;

public record CoveragePoint(

        String id,
        VoltageLevel level,

        String municipalityCode,
        String bairro,
        String sub,
        String conjunto,

        double latitude,
        double longitude,

        // quantos consumidores o registro representa: a baixa tensão é gravada por
        // ponto de conexão + classe + CNAE (#TG-144); MT/AT e dados antigos = 1
        int consumers

) {
    public CoveragePoint {
        if (consumers < 1) consumers = 1;
    }
}