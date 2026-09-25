package com.tecsys.domain.decision;

import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest
class DecisionRepositoryTest {

    private static final int GATEWAY_RANGE_METERS = 4000;

    @Autowired
    private DecisionRepository repository;

    @Autowired
    private DecisionEngine decisionEngine;

    @Test
    void shouldCalculateBestGatewayCombination() {

        DecisionCriteria criteria = new DecisionCriteria(

                
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

       
        var coveragePoints =
                repository.findCoveragePoints(criteria);

       
        var candidates =
                repository.findGatewayCandidates(criteria);

        
        var relations =
                repository.findCoverageRelations(
                        criteria,
                        GATEWAY_RANGE_METERS
                );

        
        var result =
                decisionEngine.calculate(
                        coveragePoints,
                        candidates,
                        relations
                );

        assertNotNull(result);

        System.out.println();
        System.out.println("======================================");
        System.out.println("       RESULTADO DO MOTOR");
        System.out.println("======================================");

        System.out.println(
                "Alcance: "
                + GATEWAY_RANGE_METERS
                + " metros"
        );

        System.out.println();

        System.out.println(
                "UCs analisadas: "
                + result.totalPoints()
        );

        System.out.println(
                "Candidatos analisados: "
                + result.totalCandidates()
        );

        System.out.println(
                "Gateways selecionados: "
                + result.selectedGateways().size()
        );

        System.out.println(
                "UCs cobertas: "
                + result.coveredPoints()
        );

        System.out.println(
                "UCs nao cobertas: "
                + result.uncoveredPoints()
        );

        System.out.println(
                "Cobertura: "
                + result.coveragePercentage()
                + "%"
        );

        System.out.println();

        System.out.println("Gateways escolhidos:");

        result.selectedGateways()
                .forEach(selected -> {

                    var gateway =
                            selected.candidate();

                    System.out.println();

                    System.out.println(
                            "#"
                            + selected.order()
                    );

                    System.out.println(
                            "Tipo: "
                            + gateway.type()
                    );

                    System.out.println(
                            "ID: "
                            + gateway.id()
                    );

                    System.out.println(
                            "SUB: "
                            + gateway.sub()
                    );

                    System.out.println(
                            "Posto: "
                            + gateway.posto()
                    );

                    System.out.println(
                            "Coordenadas: "
                            + gateway.latitude()
                            + ", "
                            + gateway.longitude()
                    );

                    System.out.println(
                            "Novas UCs cobertas: "
                            + selected.newPointsCovered()
                    );

                    System.out.println(
                            "UCs acumuladas: "
                            + selected.cumulativePointsCovered()
                    );

                    System.out.println(
                            "Cobertura acumulada: "
                            + selected.cumulativeCoveragePercentage()
                            + "%"
                    );
                });

        System.out.println();

        if (!result.uncoveredCoveragePoints().isEmpty()) {

            System.out.println(
                    "UCs que ficaram sem cobertura:"
            );

            result.uncoveredCoveragePoints()
                    .stream()
                    .limit(10)
                    .forEach(point ->
                            System.out.println(
                                    point.level()
                                    + " | "
                                    + point.id()
                                    + " | "
                                    + point.bairro()
                                    + " | "
                                    + point.latitude()
                                    + ", "
                                    + point.longitude()
                            )
                    );
        }

        System.out.println("======================================");
    }
}