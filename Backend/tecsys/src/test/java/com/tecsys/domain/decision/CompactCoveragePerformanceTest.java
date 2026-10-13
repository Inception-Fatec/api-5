package com.tecsys.domain.decision;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.BitSet;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(properties = {
        "spring.flyway.enabled=false",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.datasource.hikari.connection-init-sql=SET statement_timeout = 600000"
})
class CompactCoveragePerformanceTest {

    private static final int GATEWAY_RANGE_METERS = 4000;

    @Autowired
    private NamedParameterJdbcTemplate jdbcTemplate;

    @Test
    void measureCompactCoverageTransfer() {

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

        String sql = """
                WITH point_index AS (

                    SELECT
                        u.cod_id_encr AS point_id,

                        (
                            ROW_NUMBER() OVER (
                                ORDER BY u.cod_id_encr
                            ) - 1
                        )::integer AS point_index

                    FROM ucbt u

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

                    WHERE u.geom IS NOT NULL
                      AND u.mun IN (:munCodes)
                      AND u.conj IN (:conjCodes)
                      AND u.sub IN (:subCodes)
                )

                SELECT
                    c.type AS candidate_type,
                    c.id AS candidate_id,

                    ARRAY_AGG(
                        pi.point_index
                    ) AS point_indexes

                FROM gateway_candidates c

                JOIN ucbt p
                  ON p.geom IS NOT NULL

                 AND p.mun IN (:munCodes)
                 AND p.conj IN (:conjCodes)
                 AND p.sub IN (:subCodes)

                 AND ST_DWithin(
                        c.geom::geography,
                        p.geom::geography,
                        :gatewayRangeMeters
                 )

                JOIN point_index pi
                  ON pi.point_id = p.cod_id_encr

                GROUP BY
                    c.type,
                    c.id
                """;

        System.out.println();
        System.out.println("======================================");
        System.out.println("   COMPACT COVERAGE PERFORMANCE");
        System.out.println("======================================");

        long start = System.nanoTime();

        List<CandidateCompactCoverage> groups =
                jdbcTemplate.query(
                        sql,
                        params,
                        (rs, rowNum) -> {

                            String rawIndexes =
                                    rs.getString(
                                            "point_indexes"
                                    );

                            int[] indexes =
                                    parsePostgresIntArray(
                                            rawIndexes
                                    );

                            return new CandidateCompactCoverage(
                                    rs.getString(
                                            "candidate_type"
                                    ),
                                    rs.getString(
                                            "candidate_id"
                                    ),
                                    indexes
                            );
                        }
                );

        double queryTime =
                elapsed(start);

        long totalRelations = 0;

        BitSet coveredPoints =
                new BitSet();

        int largestCoverage = 0;

        String largestCandidate = null;

        for (
                CandidateCompactCoverage group :
                groups
        ) {

            totalRelations +=
                    group.pointIndexes().length;

            if (
                    group.pointIndexes().length
                    > largestCoverage
            ) {

                largestCoverage =
                        group.pointIndexes().length;

                largestCandidate =
                        group.candidateId();
            }

            for (
                    int pointIndex :
                    group.pointIndexes()
            ) {

                coveredPoints.set(
                        pointIndex
                );
            }
        }

        System.out.printf(
                "%-32s %.3f s%n",
                "Query + transferencia:",
                queryTime
        );

        System.out.println();

        System.out.println(
                "Candidatos recebidos: "
                + groups.size()
        );

        System.out.println(
                "Relacoes representadas: "
                + totalRelations
        );

        System.out.println(
                "UCs distintas representadas: "
                + coveredPoints.cardinality()
        );

        System.out.println(
                "Maior cobertura individual: "
                + largestCoverage
        );

        System.out.println(
                "Candidato com maior cobertura: "
                + largestCandidate
        );

        System.out.println();

        System.out.println(
                "Linhas trafegadas:"
        );

        System.out.println(
                "ANTES: 445603"
        );

        System.out.println(
                "AGORA: "
                + groups.size()
        );

        System.out.println(
                "Reducao de linhas: "
                + String.format(
                        "%.2fx",
                        445603.0
                        / groups.size()
                )
        );

        System.out.println("======================================");

        assertEquals(
                2602,
                groups.size()
        );

        assertEquals(
                445603,
                totalRelations
        );

        assertEquals(
                1275,
                coveredPoints.cardinality()
        );
    }

    private int[] parsePostgresIntArray(
            String value
    ) {

        if (
                value == null
                || value.length() <= 2
        ) {
            return new int[0];
        }

        int count = 1;

        for (
                int i = 1;
                i < value.length() - 1;
                i++
        ) {

            if (value.charAt(i) == ',') {
                count++;
            }
        }

        int[] result =
                new int[count];

        int resultIndex = 0;
        int number = 0;

        for (
                int i = 1;
                i < value.length() - 1;
                i++
        ) {

            char current =
                    value.charAt(i);

            if (current == ',') {

                result[resultIndex++] =
                        number;

                number = 0;

            } else {

                number =
                        number * 10
                        + (
                            current - '0'
                        );
            }
        }

        result[resultIndex] =
                number;

        return result;
    }

    private double elapsed(
            long start
    ) {

        return (
                System.nanoTime() - start
        ) / 1_000_000_000.0;
    }

    private record CandidateCompactCoverage(
            String candidateType,
            String candidateId,
            int[] pointIndexes
    ) {
    }
}