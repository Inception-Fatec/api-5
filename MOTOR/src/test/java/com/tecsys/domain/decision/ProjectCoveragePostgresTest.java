
package com.tecsys.domain.decision;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import com.tecsys.domain.decision.engine.MotorEngine;
import com.tecsys.domain.decision.engine.MotorParams;
import com.tecsys.domain.decision.engine.MotorResult;
import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import com.tecsys.domain.decision.terrain.FlatTerrain;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class ProjectCoveragePostgresTest {

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void devePersistirParametrosEManterCompatibilidade()
            throws Exception {

        
        String url = System.getenv("TG77_JDBC_URL");
        String user = System.getenv("TG77_DB_USER");
        String password = System.getenv("TG77_DB_PASSWORD");

        // Sem configuração, o teste de integração é ignorado.
        assumeTrue(
                url != null && !url.isBlank()
                        && user != null && !user.isBlank()
                        && password != null && !password.isBlank(),
                "Banco de teste TG-77 não configurado"
        );

        // Segurança: permite somente PostgreSQL local.
        // A porta e o nome do banco podem variar.
        assertTrue(
                url.matches(
                        "^jdbc:postgresql://(localhost|127\\.0\\.0\\.1)(:\\d+)?/[A-Za-z0-9_-]+$"
                ),
                "O teste TG-77 deve utilizar um PostgreSQL local"
        );


        try (Connection connection = DriverManager.getConnection(
                url, user, password)) {

            // Tabela temporária com as colunas de persistência.
            // Desaparece ao fechar esta conexão.
            try (Statement statement = connection.createStatement()) {
                statement.execute("""
                    CREATE TEMP TABLE project_coverage (
                        project_id BIGINT PRIMARY KEY,
                        summary JSONB NOT NULL,
                        gateways JSONB NOT NULL,
                        points JSONB NOT NULL,
                        calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """);
            }

            var dataSource =
                    new SingleConnectionDataSource(connection, true);

            var jdbc = new NamedParameterJdbcTemplate(dataSource);

            var repository = new ProjectCoverageRepository(jdbc);

            var service = new ProjectCoverageService(
                    repository, mapper
            );

            // ==========================================
            // TESTE 1: CÁLCULO REAL + GRAVAÇÃO EM JSONB
            // ==========================================

            var params = MotorParams.profile("tecsys")
                    .toBuilder()
                    .fixedRangeM(1000.0)
                    .useTerrain(false)
                    .lineOfSight(MotorParams.LosMode.TEAM)
                    .teamSamples(5)
                    .exactSeconds(0)
                    .localSearch(false)
                    .build();

            var pontos = List.of(
                    new CoveragePoint(
                            "p1",
                            VoltageLevel.BAIXO,
                            "3549904",
                            "Centro",
                            "S1",
                            "C1",
                            -23.0,
                            -45.0,
                            1
                    )
            );

            var candidatos = List.of(
                    new GatewayCandidate(
                            "g1",
                            CandidateType.UNTRMT,
                            "PT",
                            "S1",
                            "3549904",
                            "C1",
                            -23.0,
                            -45.0,
                            true
                    )
            );

            MotorResult result = MotorEngine.compute(
                    pontos,
                    candidatos,
                    params,
                    1000.0,
                    new FlatTerrain(),
                    1,
                    new MotorEngine.Timer()
            );

            var response = DecisionService.toResponse(
                    result, 1.25
            );

            // Executa o método REAL de persistência.
            service.saveCoverage(77L, response);

            String summarySalvo = jdbc.queryForObject(
                    """
                    SELECT summary::text
                    FROM project_coverage
                    WHERE project_id = :id
                    """,
                    Map.of("id", 77L),
                    String.class
            );

            assertNotNull(summarySalvo);

            var json = mapper.readTree(summarySalvo);

            assertEquals("tecsys", json.get("profile").asText());

            assertEquals(
                    1000,
                    json.get("gateway_range_m").asInt()
            );

            assertEquals(
                    "fixed_range",
                    json.get("range_criterion").asText()
            );

            assertEquals(
                    6.0,
                    json.get("gateway_height_m").asDouble()
            );

            assertEquals(
                    5.0,
                    json.get("sensor_height_m").asDouble()
            );

            assertFalse(
                    json.get("elevation_used").asBoolean()
            );

            assertEquals(
                    "plano",
                    json.get("elevation_source").asText()
            );

            assertEquals(
                    5,
                    json.get("los_samples").asInt()
            );

            assertEquals(
                    "TEAM",
                    json.get("los_mode").asText()
            );

            assertEquals(
                    1.25,
                    json.get("calculation_time_seconds").asDouble(),
                    0.001
            );

            System.out.println(
                    "TG-77: Novos parâmetros gravados no PostgreSQL!"
            );

            // ==========================================
            // TESTE 2: RESULTADO ANTIGO NO POSTGRESQL
            // ==========================================

            String summaryAntigo = """
                    {
                        "total_points": 10,
                        "selected_gateways": 2,
                        "gateway_range_m": 4000
                    }
                    """;

            // Simula um registro de projeto anterior à TG-77.
            repository.upsertCoverage(
                    78L,
                    summaryAntigo,
                    "[]",
                    "{\"covered\":[],\"uncovered\":[]}"
            );

            String antigoSalvo = jdbc.queryForObject(
                    """
                    SELECT summary::text
                    FROM project_coverage
                    WHERE project_id = :id
                    """,
                    Map.of("id", 78L),
                    String.class
            );

            assertNotNull(antigoSalvo);

            var jsonAntigo = mapper.readTree(antigoSalvo);

            assertEquals(
                    4000,
                    jsonAntigo.get("gateway_range_m").asInt()
            );

            assertFalse(jsonAntigo.has("elevation_used"));
            assertFalse(jsonAntigo.has("elevation_source"));

            // O DTO atual consegue ler um summary legado.
            DecisionSummaryResponseDto dtoAntigo =
                    mapper.treeToValue(
                            jsonAntigo,
                            DecisionSummaryResponseDto.class
                    );

            assertEquals(10, dtoAntigo.totalPoints());
            assertNull(dtoAntigo.elevationUsed());

            System.out.println(
                    "TG-77: Summary antigo recuperado com sucesso!"
            );
        }
    }
}
