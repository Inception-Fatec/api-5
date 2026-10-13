package com.tecsys.domain.decision;

import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;

@SpringBootTest(properties = {
        "spring.flyway.enabled=false",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.datasource.hikari.connection-init-sql=SET statement_timeout = 600000"
})
class DecisionPerformanceTest {

    private static final int GATEWAY_RANGE_METERS = 4000;

    @Autowired
    private DecisionRepository repository;

    @Autowired
    private DecisionEngine decisionEngine;

    @Test
    void measureCurrentDecisionFlow() {

        DecisionCriteria criteria =
                new DecisionCriteria(
                        List.of(),
                        List.of("3549904"),
                        List.of("17113"),
                        List.of("AVP"),
                        null,
                        List.of(VoltageLevel.BAIXO),
                        List.of(),
                        List.of(),
                        List.of()
                );

        System.out.println();
        System.out.println("======================================");
        System.out.println("       PERFORMANCE MOTOR ATUAL");
        System.out.println("======================================");

        long totalStart = System.nanoTime();

        long start = System.nanoTime();

        var coveragePoints =
                repository.findCoveragePoints(criteria);

        print(
                "findCoveragePoints",
                start,
                coveragePoints.size()
        );

        start = System.nanoTime();

        var candidates =
                repository.findGatewayCandidates(criteria);

        print(
                "findGatewayCandidates",
                start,
                candidates.size()
        );

        start = System.nanoTime();

        var relations =
                repository.findCoverageRelations(
                        criteria,
                        GATEWAY_RANGE_METERS
                );

        print(
                "findCoverageRelations",
                start,
                relations.size()
        );

        start = System.nanoTime();

        var result =
                decisionEngine.calculate(
                        coveragePoints,
                        candidates,
                        relations
                );

        System.out.printf(
                "%-32s %.3f s | %d gateways%n",
                "DecisionEngine.calculate:",
                elapsed(start),
                result.selectedGateways().size()
        );

        System.out.println();

        System.out.printf(
                "%-32s %.3f s%n",
                "TOTAL:",
                elapsed(totalStart)
        );

        System.out.println();
        System.out.println("UCs: " + result.totalPoints());
        System.out.println("Candidatos: " + result.totalCandidates());
        System.out.println("Gateways: " + result.selectedGateways().size());
        System.out.println("Cobertas: " + result.coveredPoints());
        System.out.println("Nao cobertas: " + result.uncoveredPoints());
        System.out.println("Cobertura: " + result.coveragePercentage() + "%");
        System.out.println("======================================");
    }

    private void print(
            String operation,
            long start,
            int records
    ) {
        System.out.printf(
                "%-32s %.3f s | %d registros%n",
                operation + ":",
                elapsed(start),
                records
        );
    }

    private double elapsed(long start) {
        return (
                System.nanoTime() - start
        ) / 1_000_000_000.0;
    }
}