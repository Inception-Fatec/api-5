package com.tecsys.domain.decision;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class DecisionServiceTest {

    @Autowired
    private DecisionService decisionService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void shouldReturnCompleteDecisionResponse() throws Exception {

        
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

        
        var response =
                decisionService.calculate(criteria);

        assertNotNull(response);
        assertNotNull(response.summary());
        assertNotNull(response.selectedGateways());
        assertNotNull(response.coveredPoints());
        assertNotNull(response.uncoveredPoints());

        
        assertEquals(
                response.summary().totalPoints(),
                response.summary().coveredPoints()
                        + response.summary().uncoveredPoints()
        );

        
        String json =
                objectMapper
                        .writerWithDefaultPrettyPrinter()
                        .writeValueAsString(response);

        
        Path outputPath =
                Path.of(
                        "target",
                        "decision-response.json"
                );

        Files.createDirectories(
                outputPath.getParent()
        );

        Files.writeString(
                outputPath,
                json
        );

        
        System.out.println();
        System.out.println("======================================");
        System.out.println("     RESPONSE REAL DO MOTOR");
        System.out.println("======================================");

        System.out.println(
                "Total de UCs: "
                        + response.summary().totalPoints()
        );

        System.out.println(
                "Total de candidatos: "
                        + response.summary().totalCandidates()
        );

        System.out.println(
                "Gateways selecionados: "
                        + response.summary().selectedGateways()
        );

        System.out.println(
                "UCs cobertas: "
                        + response.summary().coveredPoints()
        );

        System.out.println(
                "UCs nao cobertas: "
                        + response.summary().uncoveredPoints()
        );

        System.out.println(
                "Cobertura: "
                        + response.summary().coveragePercentage()
                        + "%"
        );

        System.out.println(
                "Alcance: "
                        + response.summary().gatewayRangeMeters()
                        + " metros"
        );

        System.out.println();

        System.out.println(
                "Gateways no response: "
                        + response.selectedGateways().size()
        );

        System.out.println(
                "Pontos cobertos no response: "
                        + response.coveredPoints().size()
        );

        System.out.println(
                "Pontos nao cobertos no response: "
                        + response.uncoveredPoints().size()
        );

        System.out.println();

        System.out.println(
                "JSON completo salvo em:"
        );

        System.out.println(
                outputPath.toAbsolutePath()
        );

       
        if (!response.selectedGateways().isEmpty()) {

            String firstGatewayJson =
                    objectMapper
                            .writerWithDefaultPrettyPrinter()
                            .writeValueAsString(
                                    response
                                            .selectedGateways()
                                            .get(0)
                            );

            System.out.println();
            System.out.println(
                    "Primeiro gateway selecionado:"
            );

            System.out.println(
                    firstGatewayJson
            );
        }

        
        if (!response.coveredPoints().isEmpty()) {

            String firstPointJson =
                    objectMapper
                            .writerWithDefaultPrettyPrinter()
                            .writeValueAsString(
                                    response
                                            .coveredPoints()
                                            .get(0)
                            );

            System.out.println();
            System.out.println(
                    "Primeira UC coberta:"
            );

            System.out.println(
                    firstPointJson
            );
        }

        System.out.println();
        System.out.println("======================================");
    }
}