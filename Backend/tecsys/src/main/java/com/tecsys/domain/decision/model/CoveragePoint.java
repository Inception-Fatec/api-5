package com.tecsys.domain.decision.model;

public record CoveragePoint(

        String id,
        VoltageLevel level,

        String municipalityCode,
        String bairro,
        String sub,
        String conjunto,

        double latitude,
        double longitude

) {
}