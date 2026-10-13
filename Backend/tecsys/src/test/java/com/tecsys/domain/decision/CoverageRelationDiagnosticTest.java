package com.tecsys.domain.decision;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;

@SpringBootTest(properties = {
        "spring.flyway.enabled=false",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.datasource.hikari.connection-init-sql=SET statement_timeout = 600000"
})
class CoverageRelationDiagnosticTest {

    private static final int GATEWAY_RANGE_METERS = 4000;

    @Autowired
    private NamedParameterJdbcTemplate jdbcTemplate;

    @Test
    void measureRelationQueryWithoutTransferringAllRelations() {

        MapSqlParameterSource params =
                new MapSqlParameterSource()
                        .addValue(
                                "munCodes",
                                List.of("3549904")
                        )
                        .addValue(
                                "conjCodes",
                                List.of("17113")
                        )
                        .addValue(
                                "subCodes",
                                List.of("AVP")
                        )
                        .addValue(
                                "gatewayRangeMeters",
                                GATEWAY_RANGE_METERS
                        );

        String baseSql = """
                WITH coverage_points AS (

                    SELECT
                        u.cod_id_encr AS id,
                        'BAIXO' AS level,
                        u.geom

                    FROM ucbt u

                    LEFT JOIN sub s
                        ON s.cod_id = u.sub

                    WHERE u.geom IS NOT NULL
                      AND u.mun IN (:munCodes)
                      AND u.conj IN (:conjCodes)
                      AND u.sub IN (:subCodes)
                ),

                gateway_candidates AS (

                    SELECT
                        u.cod_id AS id,
                        'UNTRMT' AS type,
                        u.geom

                    FROM untrmt u

                    LEFT JOIN sub s
                        ON s.cod_id = u.sub

                    WHERE u.geom IS NOT NULL
                      AND u.mun IN (:munCodes)
                      AND u.conj IN (:conjCodes)
                      AND u.sub IN (:subCodes)

                    UNION ALL

                    SELECT
                        u.cod_id AS id,
                        'UNTRAT' AS type,
                        u.geom

                    FROM untrat u

                    LEFT JOIN sub s
                        ON s.cod_id = u.sub

                    WHERE u.geom IS NOT NULL
                      AND u.mun IN (:munCodes)
                      AND u.conj IN (:conjCodes)
                      AND u.sub IN (:subCodes)
                )
                """;

        System.out.println();
        System.out.println("======================================");
        System.out.println("   DIAGNOSTICO COVERAGE RELATIONS");
        System.out.println("======================================");

        /*
         * TESTE 1
         *
         * O PostgreSQL calcula todas as relações,
         * mas devolve somente UM número para o Java.
         */
        String countSql =
                baseSql
                + """
                SELECT COUNT(*)
                FROM gateway_candidates c
                JOIN coverage_points p
                  ON ST_DWithin(
                        c.geom::geography,
                        p.geom::geography,
                        :gatewayRangeMeters
                  )
                """;

        long start = System.nanoTime();

        Long relationCount =
                jdbcTemplate.queryForObject(
                        countSql,
                        params,
                        Long.class
                );

        double countTime =
                elapsed(start);

        System.out.printf(
                "%-32s %.3f s | %d relações%n",
                "COUNT total:",
                countTime,
                relationCount
        );

        /*
         * TESTE 2
         *
         * O PostgreSQL calcula as mesmas relações,
         * mas devolve somente uma linha
         * por candidato.
         */
        String groupedSql =
                baseSql
                + """
                SELECT
                    c.type AS candidate_type,
                    c.id AS candidate_id,
                    COUNT(*) AS coverage_count

                FROM gateway_candidates c

                JOIN coverage_points p
                  ON ST_DWithin(
                        c.geom::geography,
                        p.geom::geography,
                        :gatewayRangeMeters
                  )

                GROUP BY
                    c.type,
                    c.id
                """;

        start = System.nanoTime();

        var grouped =
                jdbcTemplate.query(
                        groupedSql,
                        params,
                        (rs, rowNum) ->
                                new CandidateCoverageCount(
                                        rs.getString(
                                                "candidate_type"
                                        ),
                                        rs.getString(
                                                "candidate_id"
                                        ),
                                        rs.getLong(
                                                "coverage_count"
                                        )
                                )
                );

        double groupedTime =
                elapsed(start);

        System.out.printf(
                "%-32s %.3f s | %d candidatos%n",
                "GROUP BY candidato:",
                groupedTime,
                grouped.size()
        );

        System.out.println();
        System.out.println(
                "Total de relações: "
                + relationCount
        );

        System.out.println(
                "Candidatos retornados no GROUP BY: "
                + grouped.size()
        );

        System.out.println("======================================");
    }

    private double elapsed(long start) {

        return (
                System.nanoTime() - start
        ) / 1_000_000_000.0;
    }

    private record CandidateCoverageCount(
            String type,
            String candidateId,
            long coverageCount
    ) {
    }
}