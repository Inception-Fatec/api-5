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

    /** Muda o status e limpa o motivo de falha anterior. */
    public void updateStatus(long projectId, String status) {
        updateStatus(projectId, status, null);
    }

    /** Muda o status com o motivo (usado no FALHA, #TG-84), que a tela mostra. */
    public void updateStatus(long projectId, String status, String message) {
        String sql = """
                UPDATE projects
                SET status = :status, status_message = :message
                WHERE id = :projectId
                """;

        String motivo = message;
        if (motivo != null && motivo.length() > 500) motivo = motivo.substring(0, 500);

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("projectId", projectId)
                .addValue("status", status)
                .addValue("message", motivo);

        jdbcTemplate.update(sql, params);
    }
}