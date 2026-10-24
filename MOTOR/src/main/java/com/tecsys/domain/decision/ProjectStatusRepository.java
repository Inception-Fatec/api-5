package com.tecsys.domain.decision;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ProjectStatusRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public ProjectStatusRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void updateStatus(long projectId, String status) {
        String sql = """
                UPDATE projects
                SET status = :status
                WHERE id = :projectId
                """;

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("projectId", projectId)
                .addValue("status", status);

        jdbcTemplate.update(sql, params);
    }
}