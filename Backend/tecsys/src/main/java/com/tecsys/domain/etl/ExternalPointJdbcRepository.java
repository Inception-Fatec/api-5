package com.tecsys.domain.etl;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
@RequiredArgsConstructor
public class ExternalPointJdbcRepository {

    private static final String INSERT_SQL = """
            INSERT INTO external_points (dist, mun, external_id, papel, descricao, geom, created_by)
            VALUES (?, ?, ?, ?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4674), ?)
            ON CONFLICT (dist, external_id) DO NOTHING
            """;

    private final JdbcTemplate jdbcTemplate;

    @Transactional
    public int inserirNovos(String dist, String mun, List<ExternalPointRow> pontos, Long userId) {
        int inseridos = 0;
        for (ExternalPointRow p : pontos) {
            inseridos += jdbcTemplate.update(
                    INSERT_SQL,
                    dist,
                    mun,
                    p.externalId(),
                    p.papel(),
                    p.descricao(),
                    p.longitude(),
                    p.latitude(),
                    userId
            );
        }
        return inseridos;
    }
}