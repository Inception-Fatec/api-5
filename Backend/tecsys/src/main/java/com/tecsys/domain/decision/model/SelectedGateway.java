package com.tecsys.domain.decision.model;

public record SelectedGateway(

        int order,

        GatewayCandidate candidate,

        int newPointsCovered,

        int cumulativePointsCovered,

        double cumulativeCoveragePercentage

) {
}