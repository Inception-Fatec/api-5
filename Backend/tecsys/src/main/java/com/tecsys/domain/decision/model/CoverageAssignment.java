package com.tecsys.domain.decision.model;

public record CoverageAssignment(

        CoveragePoint point,

        GatewayCandidate gateway,

        int gatewayOrder

) {
}