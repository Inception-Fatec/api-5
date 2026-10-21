package com.tecsys.domain.decision;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ProjectCoverageRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public ProjectCoverageRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void upsertCoverage(long projectId, String summaryJson, String gatewaysJson, String pointsJson) {
        String sql = """
                INSERT INTO project_coverage (project_id, summary, gateways, points)
                VALUES (:projectId, :summary::jsonb, :gateways::jsonb, :points::jsonb)
                ON CONFLICT (project_id)
                DO UPDATE SET
                    summary  = EXCLUDED.summary,
                    gateways = EXCLUDED.gateways,
                    points   = EXCLUDED.points
                """;

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("projectId", projectId)
                .addValue("summary", summaryJson)
                .addValue("gateways", gatewaysJson)
                .addValue("points", pointsJson);

        jdbcTemplate.update(sql, params);
    }
}