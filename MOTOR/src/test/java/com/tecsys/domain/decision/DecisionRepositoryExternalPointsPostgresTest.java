package com.tecsys.domain.decision;

import com.tecsys.domain.decision.engine.MotorEngine;
import com.tecsys.domain.decision.engine.MotorParams;
import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import com.tecsys.domain.decision.terrain.FlatTerrain;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class DecisionRepositoryExternalPointsPostgresTest {

    @Test
    void deveConsultarPontosExternosRespeitandoPapelERegiao() throws Exception {
        String url = System.getenv("TG91_JDBC_URL");
        String user = System.getenv("TG91_DB_USER");
        String password = System.getenv("TG91_DB_PASSWORD");

        // Sem as variaveis de ambiente, o teste de integracao e ignorado.
        assumeTrue(
                url != null && !url.isBlank()
                        && user != null && !user.isBlank()
                        && password != null && !password.isBlank(),
                "Banco de teste TG-91 nao configurado"
        );

        // Impede conexao acidental com um banco remoto.
        assertTrue(
                url.matches("^jdbc:postgresql://(localhost|127\\.0\\.0\\.1):\\d+/tecsys$"),
                "O teste deve utilizar o PostgreSQL local de testes"
        );

        try (Connection connection = DriverManager.getConnection(url, user, password)) {
            try (Statement statement = connection.createStatement()) {
                try (ResultSet rs = statement.executeQuery(
                        "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis')")) {
                    rs.next();
                    assumeTrue(rs.getBoolean(1), "A extensao PostGIS precisa estar habilitada");
                }

                // Tabela temporaria: nao altera a tabela permanente e desaparece ao fechar a conexao.
                statement.execute("""
                        CREATE TEMP TABLE external_points (
                            dist VARCHAR(100) NOT NULL,
                            mun VARCHAR(10) NOT NULL,
                            external_id VARCHAR(100) NOT NULL,
                            papel VARCHAR(20) NOT NULL,
                            geom geometry(Point, 4674) NOT NULL
                        )
                        """);

                statement.execute("""
                        INSERT INTO external_points (dist, mun, external_id, papel, geom)
                        VALUES
                            ('391', '3549904', 'P01', 'ponto_a_cobrir',
                                ST_SetSRID(ST_MakePoint(-45.9009, -23.2237), 4674)),
                            ('391', '3549904', 'P02', 'ponto_a_cobrir',
                                ST_SetSRID(ST_MakePoint(-45.8900, -23.2250), 4674)),
                            ('391', '3549904', 'C01', 'candidato',
                                ST_SetSRID(ST_MakePoint(-45.8800, -23.2100), 4674)),
                            ('391', '3549904', 'I01', 'interesse',
                                ST_SetSRID(ST_MakePoint(-45.8700, -23.2100), 4674)),
                            ('392', '3549904', 'P03', 'ponto_a_cobrir',
                                ST_SetSRID(ST_MakePoint(-45.8600, -23.2200), 4674)),
                            ('391', '3550308', 'P04', 'ponto_a_cobrir',
                                ST_SetSRID(ST_MakePoint(-46.6300, -23.5500), 4674))
                        """);
            }

            // A mesma conexao permite consultar a tabela temporaria.
            var dataSource = new SingleConnectionDataSource(connection, true);
            var jdbc = new NamedParameterJdbcTemplate(dataSource);
            var repository = new DecisionRepository(jdbc);

            DecisionCriteria criteria = new DecisionCriteria(
                    List.of("391"),
                    List.of("3549904"),
                    List.of(),
                    List.of(),
                    null,
                    List.of(VoltageLevel.ALTO, VoltageLevel.MEDIO, VoltageLevel.BAIXO),
                    List.of(),
                    List.of(),
                    List.of(),
                    List.of("external_points"),
                    List.of("external_points")
            );

            // Somente P01 e P02 sao pontos a cobrir dentro da distribuidora e do municipio.
            List<CoveragePoint> points = repository.findCoveragePoints(criteria, true);
            assertEquals(2, points.size());

            Set<String> ids = points.stream()
                    .map(CoveragePoint::id)
                    .collect(Collectors.toSet());
            assertEquals(Set.of("CSV:391:P01", "CSV:391:P02"), ids);

            for (CoveragePoint point : points) {
                assertEquals(VoltageLevel.EXTERNO, point.level());
                assertEquals(1, point.consumers());
                assertEquals("3549904", point.municipalityCode());
                assertTrue(Double.isFinite(point.latitude()));
                assertTrue(Double.isFinite(point.longitude()));
            }

            // C01 e o unico candidato externo valido na regiao.
            List<GatewayCandidate> candidates = repository.findGatewayCandidates(
                    criteria, false, 3000.0, true
            );
            assertEquals(1, candidates.size());

            GatewayCandidate gateway = candidates.get(0);
            assertEquals("CSV:391:C01", gateway.id());
            assertEquals(CandidateType.EXTERNO, gateway.type());
            assertEquals("3549904", gateway.municipalityCode());
            assertTrue(gateway.insideFilters());

            System.out.println("TG-91: Candidato externo encontrado no PostgreSQL!");

            // A busca por vizinhanca tambem deve encontrar C01.
            List<GatewayCandidate> neighborCandidates = repository.findGatewayCandidates(
                    criteria, true, 3000.0, true
            );
            assertEquals(1, neighborCandidates.size());
            assertEquals("CSV:391:C01", neighborCandidates.get(0).id());
            assertTrue(neighborCandidates.get(0).insideFilters());

            // Poligono contem P01 e P02, mas deixa C01 fora da area.
            DecisionCriteria criteriaComArea = new DecisionCriteria(
                    criteria.distCodes(),
                    criteria.munCodes(),
                    criteria.conjCodes(),
                    criteria.subCodes(),
                    """
                    {
                      "type": "Polygon",
                      "coordinates": [[
                        [-45.910, -23.230],
                        [-45.885, -23.230],
                        [-45.885, -23.220],
                        [-45.910, -23.220],
                        [-45.910, -23.230]
                      ]]
                    }
                    """,
                    criteria.targetLevels(),
                    criteria.clasSub(),
                    criteria.cnaeCodes(),
                    criteria.bairroNames(),
                    criteria.coverageLayers(),
                    criteria.candidateLayers()
            );

            // Sem busca por vizinhanca, o candidato externo fora do poligono nao entra.
            List<GatewayCandidate> candidatosDentro = repository.findGatewayCandidates(
                    criteriaComArea, false, 3000.0, true
            );
            assertTrue(candidatosDentro.isEmpty());

            // Com vizinhanca, C01 entra por estar a menos de 3000 m dos pontos.
            List<GatewayCandidate> candidatosVizinhos = repository.findGatewayCandidates(
                    criteriaComArea, true, 3000.0, true
            );
            assertEquals(1, candidatosVizinhos.size());
            assertEquals("CSV:391:C01", candidatosVizinhos.get(0).id());
            assertFalse(candidatosVizinhos.get(0).insideFilters());

            System.out.println("TG-91: Candidato fora da area encontrado por vizinhanca!");

            // O motor deve escolher o gateway CSV e contabilizar os pontos externos.
            MotorParams motorParams = MotorParams.profile("tecsys")
                    .toBuilder()
                    .fixedRangeM(3000.0)
                    .useTerrain(false)
                    .exactSeconds(0)
                    .build();

            var result = MotorEngine.compute(
                    points,
                    candidates,
                    motorParams,
                    3000.0,
                    new FlatTerrain(),
                    2,
                    new MotorEngine.Timer()
            );

            var response = DecisionService.toResponse(result, 0.1);

            assertEquals(2, response.summary().totalPoints());
            assertEquals(2L, response.summary().totalConsumers());
            assertEquals(2, response.summary().coveredPoints());
            assertEquals(2L, response.summary().coveredConsumers());
            assertEquals(100.0, response.summary().coveragePercentage(), 0.01);
            assertEquals(1, response.summary().totalCandidates());
            assertEquals(1, response.summary().selectedGateways());
            assertEquals("CSV:391:C01", response.selectedGateways().get(0).id());

            System.out.println("TG-91: Pontos CSV contabilizados no resumo do relatorio!");
            System.out.println("TG-91: Pontos externos consultados no PostgreSQL!");
            System.out.println("TG-91: Filtros de papel, distribuidora e municipio corretos!");
        }
    }
}
