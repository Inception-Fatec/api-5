package com.tecsys.domain.point;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.point.dto.PointFilterRequestDto;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * TG-91: verifica a consulta SQL real de pontos e candidatos CSV no mapa.
 * Usa tabela TEMPORARIA e um PostgreSQL/PostGIS local dedicado a testes.
 */
class PointExternalLayersPostgresTest {

    @Test
    void contaPontosECandidatosExternosRespeitandoPapelEDelimitadores() throws Exception {
        String url = System.getenv("TG91_JDBC_URL");
        String user = System.getenv("TG91_DB_USER");
        String password = System.getenv("TG91_DB_PASSWORD");

        assertNotNull(url, "Configure TG91_JDBC_URL para o PostgreSQL local de testes");
        assertNotNull(user, "Configure TG91_DB_USER");
        assertNotNull(password, "Configure TG91_DB_PASSWORD");
        assertTrue(url.matches("^jdbc:postgresql://(localhost|127\\.0\\.0\\.1):\\d+/tecsys$"),
                "Este teste aceita somente o banco local tecsys; nao use producao");

        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            try (Statement stmt = conn.createStatement()) {
                try (ResultSet rs = stmt.executeQuery(
                        "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis')")) {
                    assertTrue(rs.next() && rs.getBoolean(1), "PostGIS nao esta habilitado");
                }

                // A tabela temporaria tem prioridade sobre qualquer tabela de mesmo nome
                // nesta conexao e desaparece automaticamente quando ela e fechada.
                stmt.execute("""
                        CREATE TEMP TABLE external_points (
                            dist VARCHAR(100),
                            mun VARCHAR(10),
                            external_id VARCHAR(100),
                            papel VARCHAR(20),
                            geom geometry(Point, 4674)
                        )
                        """);

                stmt.execute("""
                        INSERT INTO external_points (dist, mun, external_id, papel, geom)
                        VALUES
                          ('391', '3549904', 'P01', 'ponto_a_cobrir', ST_SetSRID(ST_MakePoint(-45.895, -23.224), 4674)),
                          ('391', '3549904', 'P02', 'ponto_a_cobrir', ST_SetSRID(ST_MakePoint(-45.896, -23.225), 4674)),
                          ('391', '3549904', 'C01', 'candidato',      ST_SetSRID(ST_MakePoint(-45.897, -23.226), 4674)),
                          ('391', '3549904', 'I01', 'interesse',      ST_SetSRID(ST_MakePoint(-45.898, -23.227), 4674)),
                          ('392', '3549904', 'P03', 'ponto_a_cobrir', ST_SetSRID(ST_MakePoint(-45.899, -23.228), 4674)),
                          ('391', '3550308', 'C02', 'candidato',      ST_SetSRID(ST_MakePoint(-46.630, -23.550), 4674))
                        """);
            }

            var jdbc = new NamedParameterJdbcTemplate(new SingleConnectionDataSource(conn, true));
            var repository = new PointCustomRepository(jdbc, new ObjectMapper());

            // count_only=true evita consultar outras tabelas BDGD; assim o teste
            // roda no contêiner PostGIS vazio usado nos testes do Motor.
            var request = new PointFilterRequestDto(
                    List.of("391"),                     // distribuidora
                    List.of("3549904"),                 // municipio
                    null, null, null, null,
                    List.of("baixo"),                   // tensao nao limita o CSV
                    null, null, null,
                    List.of("external_points"),         // pontos a cobrir
                    List.of("external_points"),         // candidatos
                    true,                               // count_only
                    null, null
            );

            var response = repository.executeSpatialFilter(request);
            assertEquals(2L, response.totalPoints());
            assertEquals(1L, response.totalCandidates());
            assertEquals(0L, response.totalNetwork());
            assertEquals(0, response.features().path("features").size());

            System.out.println("TG-91 Backend: 2 pontos CSV e 1 candidato CSV contados no PostgreSQL!");
            System.out.println("TG-91 Backend: papel, distribuidora, municipio e tensao validados!");
        }
    }
}
