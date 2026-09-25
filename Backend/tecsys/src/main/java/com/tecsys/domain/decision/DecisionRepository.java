package com.tecsys.domain.decision;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.CoverageRelation;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;

@Repository
public class DecisionRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public DecisionRepository(
            NamedParameterJdbcTemplate jdbcTemplate
    ) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<CoveragePoint> findCoveragePoints(
            DecisionCriteria criteria
    ) {

        List<TargetTable> targetTables =
                resolveTargetTables(criteria.targetLevels());

        if (targetTables.isEmpty()) {
            return List.of();
        }

        MapSqlParameterSource params =
                createParameters(criteria);

        List<String> selects = new ArrayList<>();

        for (TargetTable target : targetTables) {

            selects.add(
                    buildCoveragePointQuery(
                            target,
                            criteria
                    )
            );
        }

        String sql = String.join(
                "\nUNION ALL\n",
                selects
        );

        return jdbcTemplate.query(
                sql,
                params,
                (rs, rowNum) -> new CoveragePoint(
                        rs.getString("id"),

                        VoltageLevel.valueOf(
                                rs.getString("level")
                        ),

                        rs.getString("mun"),
                        rs.getString("brr"),
                        rs.getString("sub"),
                        rs.getString("conj"),

                        rs.getDouble("latitude"),
                        rs.getDouble("longitude")
                )
        );
    }

    public List<GatewayCandidate> findGatewayCandidates(
            DecisionCriteria criteria
    ) {

        MapSqlParameterSource params =
                createParameters(criteria);

        List<String> selects = List.of(
                buildUntrmtQuery(criteria),
                buildUntratQuery(criteria)
        );

        String sql = String.join(
                "\nUNION ALL\n",
                selects
        );

        return jdbcTemplate.query(
                sql,
                params,
                (rs, rowNum) -> new GatewayCandidate(
                        rs.getString("id"),

                        CandidateType.valueOf(
                                rs.getString("type")
                        ),

                        rs.getString("posto"),
                        rs.getString("sub"),
                        rs.getString("mun"),
                        rs.getString("conj"),

                        rs.getDouble("latitude"),
                        rs.getDouble("longitude")
                )
        );
    }

    public List<CoverageRelation> findCoverageRelations(
            DecisionCriteria criteria,
            int gatewayRangeMeters
    ) {

        if (gatewayRangeMeters <= 0) {
            throw new IllegalArgumentException(
                    "O alcance do gateway deve ser maior que zero."
            );
        }

        List<TargetTable> targetTables =
                resolveTargetTables(criteria.targetLevels());

        if (targetTables.isEmpty()) {
            return List.of();
        }

        MapSqlParameterSource params =
                createParameters(criteria);

        params.addValue(
                "gatewayRangeMeters",
                gatewayRangeMeters
        );

        List<String> pointQueries =
                new ArrayList<>();

        for (TargetTable target : targetTables) {

            pointQueries.add(
                    buildCoverageSourceQuery(
                            target,
                            criteria
                    )
            );
        }

        String pointsSql = String.join(
                "\nUNION ALL\n",
                pointQueries
        );

        String candidatesSql =
                buildCandidateCoverageSource(criteria);

        String sql = """
                WITH coverage_points AS (
                    %s
                ),
                gateway_candidates AS (
                    %s
                )
                SELECT
                    c.type AS candidate_type,
                    c.id AS candidate_id,
                    p.level AS point_level,
                    p.id AS point_id
                FROM gateway_candidates c
                JOIN coverage_points p
                  ON ST_DWithin(
                        c.geom::geography,
                        p.geom::geography,
                        :gatewayRangeMeters
                  )
                """.formatted(
                pointsSql,
                candidatesSql
        );

        return jdbcTemplate.query(
                sql,
                params,
                (rs, rowNum) -> new CoverageRelation(

                        CandidateType.valueOf(
                                rs.getString(
                                        "candidate_type"
                                )
                        ),

                        rs.getString(
                                "candidate_id"
                        ),

                        VoltageLevel.valueOf(
                                rs.getString(
                                        "point_level"
                                )
                        ),

                        rs.getString(
                                "point_id"
                        )
                )
        );
    }

    private String buildCoveragePointQuery(
            TargetTable target,
            DecisionCriteria criteria
    ) {

        StringBuilder sql =
                new StringBuilder();

        sql.append("""
                SELECT
                    u.cod_id_encr AS id,
                    '%s' AS level,
                    u.mun,
                    u.brr,
                    u.sub,
                    u.conj,

                    ST_Y(
                        ST_Transform(
                            u.geom,
                            4326
                        )
                    ) AS latitude,

                    ST_X(
                        ST_Transform(
                            u.geom,
                            4326
                        )
                    ) AS longitude

                FROM %s u

                LEFT JOIN sub s
                    ON s.cod_id = u.sub

                WHERE u.geom IS NOT NULL
                """.formatted(
                target.level().name(),
                target.tableName()
        ));

        appendConsumerFilters(
                sql,
                criteria
        );

        return sql.toString();
    }

    private String buildCoverageSourceQuery(
            TargetTable target,
            DecisionCriteria criteria
    ) {

        StringBuilder sql =
                new StringBuilder();

        sql.append("""
                SELECT
                    u.cod_id_encr AS id,
                    '%s' AS level,
                    u.geom

                FROM %s u

                LEFT JOIN sub s
                    ON s.cod_id = u.sub

                WHERE u.geom IS NOT NULL
                """.formatted(
                target.level().name(),
                target.tableName()
        ));

        appendConsumerFilters(
                sql,
                criteria
        );

        return sql.toString();
    }

    private String buildUntrmtQuery(
            DecisionCriteria criteria
    ) {

        StringBuilder sql =
                new StringBuilder("""
                        SELECT
                            u.cod_id AS id,
                            'UNTRMT' AS type,
                            u.posto,
                            u.sub,
                            u.mun,
                            u.conj,

                            ST_Y(
                                ST_Transform(
                                    u.geom,
                                    4326
                                )
                            ) AS latitude,

                            ST_X(
                                ST_Transform(
                                    u.geom,
                                    4326
                                )
                            ) AS longitude

                        FROM untrmt u

                        LEFT JOIN sub s
                            ON s.cod_id = u.sub

                        WHERE u.geom IS NOT NULL
                        """);

        appendCandidateFilters(
                sql,
                criteria
        );

        return sql.toString();
    }

    private String buildUntratQuery(
            DecisionCriteria criteria
    ) {

        StringBuilder sql =
                new StringBuilder("""
                        SELECT
                            u.cod_id AS id,
                            'UNTRAT' AS type,

                            NULL::text AS posto,

                            u.sub,
                            u.mun,
                            u.conj,

                            ST_Y(
                                ST_Transform(
                                    u.geom,
                                    4326
                                )
                            ) AS latitude,

                            ST_X(
                                ST_Transform(
                                    u.geom,
                                    4326
                                )
                            ) AS longitude

                        FROM untrat u

                        LEFT JOIN sub s
                            ON s.cod_id = u.sub

                        WHERE u.geom IS NOT NULL
                        """);

        appendCandidateFilters(
                sql,
                criteria
        );

        return sql.toString();
    }

    private String buildCandidateCoverageSource(
            DecisionCriteria criteria
    ) {

        StringBuilder untrmt =
                new StringBuilder("""
                        SELECT
                            u.cod_id AS id,
                            'UNTRMT' AS type,
                            u.geom

                        FROM untrmt u

                        LEFT JOIN sub s
                            ON s.cod_id = u.sub

                        WHERE u.geom IS NOT NULL
                        """);

        appendCandidateFilters(
                untrmt,
                criteria
        );

        StringBuilder untrat =
                new StringBuilder("""
                        SELECT
                            u.cod_id AS id,
                            'UNTRAT' AS type,
                            u.geom

                        FROM untrat u

                        LEFT JOIN sub s
                            ON s.cod_id = u.sub

                        WHERE u.geom IS NOT NULL
                        """);

        appendCandidateFilters(
                untrat,
                criteria
        );

        return untrmt.toString()
                + "\nUNION ALL\n"
                + untrat;
    }

    private void appendConsumerFilters(
            StringBuilder sql,
            DecisionCriteria criteria
    ) {

        appendCommonFilters(
                sql,
                criteria
        );

        if (!criteria.clasSub().isEmpty()) {

            sql.append(
                    " AND u.clas_sub IN (:clasSub) "
            );
        }

        if (!criteria.cnaeCodes().isEmpty()) {

            sql.append(
                    " AND u.cnae IN (:cnaeCodes) "
            );
        }

        if (!criteria.bairroNames().isEmpty()) {

            sql.append(
                    " AND u.brr IN (:bairroNames) "
            );
        }
    }

    private void appendCandidateFilters(
            StringBuilder sql,
            DecisionCriteria criteria
    ) {

        appendCommonFilters(
                sql,
                criteria
        );
    }

    private void appendCommonFilters(
            StringBuilder sql,
            DecisionCriteria criteria
    ) {

        if (!criteria.distCodes().isEmpty()) {

            sql.append(
                    " AND s.dist IN (:distCodes) "
            );
        }

        if (!criteria.munCodes().isEmpty()) {

            sql.append(
                    " AND u.mun IN (:munCodes) "
            );
        }

        if (!criteria.conjCodes().isEmpty()) {

            sql.append(
                    " AND u.conj IN (:conjCodes) "
            );
        }

        if (!criteria.subCodes().isEmpty()) {

            sql.append(
                    " AND u.sub IN (:subCodes) "
            );
        }

        if (criteria.hasPolygon()) {

            sql.append("""
                     AND ST_Intersects(
                         u.geom,
                         ST_Transform(
                             ST_GeomFromGeoJSON(
                                 :polygonGeojson
                             ),
                             4674
                         )
                     )
                    """);
        }
    }

    private MapSqlParameterSource createParameters(
            DecisionCriteria criteria
    ) {

        MapSqlParameterSource params =
                new MapSqlParameterSource();

        if (!criteria.distCodes().isEmpty()) {

            params.addValue(
                    "distCodes",
                    criteria.distCodes()
            );
        }

        if (!criteria.munCodes().isEmpty()) {

            params.addValue(
                    "munCodes",
                    criteria.munCodes()
            );
        }

        if (!criteria.conjCodes().isEmpty()) {

            params.addValue(
                    "conjCodes",
                    criteria.conjCodes()
            );
        }

        if (!criteria.subCodes().isEmpty()) {

            params.addValue(
                    "subCodes",
                    criteria.subCodes()
            );
        }

        if (!criteria.clasSub().isEmpty()) {

            params.addValue(
                    "clasSub",
                    criteria.clasSub()
            );
        }

        if (!criteria.cnaeCodes().isEmpty()) {

            params.addValue(
                    "cnaeCodes",
                    criteria.cnaeCodes()
            );
        }

        if (!criteria.bairroNames().isEmpty()) {

            params.addValue(
                    "bairroNames",
                    criteria.bairroNames()
            );
        }

        if (criteria.hasPolygon()) {

            params.addValue(
                    "polygonGeojson",
                    criteria.polygonGeojson()
            );
        }

        return params;
    }

    private List<TargetTable> resolveTargetTables(
            List<VoltageLevel> targetLevels
    ) {

        List<TargetTable> all =
                List.of(

                        new TargetTable(
                                "ucat_pj",
                                VoltageLevel.ALTO
                        ),

                        new TargetTable(
                                "ucmt_pj",
                                VoltageLevel.MEDIO
                        ),

                        new TargetTable(
                                "ucbt",
                                VoltageLevel.BAIXO
                        )
                );

        if (
                targetLevels == null
                || targetLevels.isEmpty()
        ) {

            return all;
        }

        return all.stream()
                .filter(target ->
                        targetLevels.contains(
                                target.level()
                        )
                )
                .toList();
    }

    private record TargetTable(
            String tableName,
            VoltageLevel level
    ) {
    }
}