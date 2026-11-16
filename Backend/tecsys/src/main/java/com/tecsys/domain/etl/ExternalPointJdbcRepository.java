package com.tecsys.domain.etl;

import com.tecsys.domain.etl.dto.ExternalPointResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class ExternalPointJdbcRepository {

    private static final String INSERT_SQL = """
            INSERT INTO external_points (dist, mun, external_id, papel, descricao, geom, created_by)
            VALUES (?, ?, ?, ?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4674), ?)
            ON CONFLICT (dist, external_id) DO NOTHING
            """;

    // (dist, external_id) é único: os ids gravados por uma importação
    // identificam os pontos dela sem coluna nova na tabela.
    private static final String LISTAR_POR_IDS_SQL = """
            SELECT external_id, papel, descricao, ST_Y(geom) AS latitude, ST_X(geom) AS longitude
            FROM external_points
            WHERE dist = ? AND external_id = ANY (?)
            ORDER BY id
            """;

    private final JdbcTemplate jdbcTemplate;

    /**
     * Grava os pontos que ainda não existem (por distribuidora + id) e devolve
     * os ids que entraram agora; os já existentes são ignorados.
     */
    @Transactional
    public List<String> inserirNovos(String dist, String mun, List<ExternalPointRow> pontos, Long userId) {
        List<String> inseridos = new ArrayList<>();
        for (ExternalPointRow p : pontos) {
            int linhas = jdbcTemplate.update(
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
            if (linhas > 0) {
                inseridos.add(p.externalId());
            }
        }
        return inseridos;
    }

    /** Pontos de uma distribuidora pelos ids do CSV, na ordem em que foram gravados. */
    public List<ExternalPointResponseDto> listarPorIds(String dist, List<String> externalIds) {
        if (externalIds.isEmpty()) {
            return List.of();
        }
        return jdbcTemplate.query(LISTAR_POR_IDS_SQL,
                ps -> {
                    ps.setString(1, dist);
                    ps.setArray(2, ps.getConnection().createArrayOf("text", externalIds.toArray()));
                },
                (rs, i) -> new ExternalPointResponseDto(
                        rs.getString("external_id"),
                        rs.getString("papel"),
                        rs.getString("descricao"),
                        rs.getDouble("latitude"),
                        rs.getDouble("longitude")));
    }
}
