package com.tecsys.domain.decision.model;

public record GatewayCandidate(

        String id,
        CandidateType type,

        String posto,
        String sub,
        String municipalityCode,
        String conjunto,

        double latitude,
        double longitude,

        // false = trafo fora dos filtros do projeto, mas ao alcance da área (#TG-138)
        boolean insideFilters

) {
}
