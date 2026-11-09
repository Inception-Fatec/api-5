package com.tecsys.domain.decision.model;

public record SelectedGateway(

        int order,

        GatewayCandidate candidate,

        int newPointsCovered,

        int cumulativePointsCovered,

        // consumidores (peso dos pontos, #TG-144); o percentual é sobre consumidores
        long newConsumersCovered,

        long cumulativeConsumersCovered,

        double cumulativeCoveragePercentage

) {
}