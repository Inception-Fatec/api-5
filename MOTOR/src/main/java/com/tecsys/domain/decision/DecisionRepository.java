package com.tecsys.domain.decision;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;

/**
 * Leitura do PostGIS com os mesmos filtros de {@code filter_params} usados pelo sistema.
 * Pontos: consumidores {@code ucat_pj}, {@code ucmt_pj} e {@code ucbt}. Candidatos: transformadores
 * {@code untrmt} e {@code untrat}.
 */
@Repository
public class DecisionRepository {

    private static final List<TargetTable> POINT_TABLES = List.of(
            new TargetTable("ucat_pj", VoltageLevel.ALTO),
            new TargetTable("ucmt_pj", VoltageLevel.MEDIO),
            new TargetTable("ucbt", VoltageLevel.BAIXO));

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public DecisionRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<CoveragePoint> findCoveragePoints(DecisionCriteria criteria, boolean bairroLikeMap) {
        MapSqlParameterSource params = new MapSqlParameterSource();
        String points = pointsSource(criteria, bairroLikeMap, params);
        if (points == null) return List.of();

        String sql = """
                SELECT id, level, mun, brr, sub, conj,
                       ST_Y(ST_Transform(geom, 4326)) AS latitude,
                       ST_X(ST_Transform(geom, 4326)) AS longitude
                FROM (%s) t
                """.formatted(points);

        return jdbcTemplate.query(sql, params, (rs, i) -> new CoveragePoint(
                rs.getString("id"),
                VoltageLevel.valueOf(rs.getString("level")),
                rs.getString("mun"),
                rs.getString("brr"),
                rs.getString("sub"),
                rs.getString("conj"),
                rs.getDouble("latitude"),
                rs.getDouble("longitude")));
    }

    /**
     * Transformadores candidatos a gateway.
     *
     * @param neighbors false: mesmos filtros dos pontos (cidade, área, conjunto, subestação).
     *                  true: qualquer trafo da distribuidora a até {@code radiusM} da área dos pontos
     *                  (#TG-138). {@code insideFilters} diz se ele passaria nos filtros.
     */
    public List<GatewayCandidate> findGatewayCandidates(DecisionCriteria criteria, boolean neighbors,
                                                        double radiusM, boolean bairroLikeMap) {
        MapSqlParameterSource params = new MapSqlParameterSource();
        String inside = commonFilters(criteria, params);

        List<String> selects = new ArrayList<>();
        for (String[] t : new String[][]{{"untrmt", "UNTRMT", "u.posto"}, {"untrat", "UNTRAT", "NULL::text"}}) {
            StringBuilder sql = new StringBuilder("""
                    SELECT u.cod_id AS id, '%s' AS type, %s AS posto, u.sub, u.mun, u.conj,
                           ST_Y(ST_Transform(u.geom, 4326)) AS latitude,
                           ST_X(ST_Transform(u.geom, 4326)) AS longitude,
                           (TRUE %s) AS inside
                    FROM %s u
                    LEFT JOIN sub s ON s.cod_id = u.sub
                    WHERE u.geom IS NOT NULL
                    """.formatted(t[1], t[2], inside, t[0]));
            if (neighbors) {
                if (!criteria.distCodes().isEmpty()) sql.append(" AND s.dist IN (:distCodes) ");
                sql.append(" AND ST_DWithin(u.geom::geography, (SELECT g FROM area)::geography, :radiusM) ");
            } else {
                sql.append(inside);
            }
            selects.add(sql.toString());
        }

        String sql = String.join("\nUNION ALL\n", selects);
        if (neighbors) {
            String points = pointsSource(criteria, bairroLikeMap, params);
            if (points == null) return List.of();
            sql = """
                    WITH pts AS (%s),
                    area AS (SELECT ST_ConvexHull(ST_Collect(geom)) AS g FROM pts)
                    %s
                    """.formatted(points, sql);
            params.addValue("radiusM", radiusM);
        }

        return jdbcTemplate.query(sql, params, (rs, i) -> new GatewayCandidate(
                rs.getString("id"),
                CandidateType.valueOf(rs.getString("type")),
                rs.getString("posto"),
                rs.getString("sub"),
                rs.getString("mun"),
                rs.getString("conj"),
                rs.getDouble("latitude"),
                rs.getDouble("longitude"),
                rs.getBoolean("inside")));
    }

    /** UNION dos consumidores filtrados, com a geometria original. Null se nenhum nível foi pedido. */
    private String pointsSource(DecisionCriteria criteria, boolean bairroLikeMap, MapSqlParameterSource params) {
        List<String> parts = new ArrayList<>();
        for (TargetTable t : POINT_TABLES) {
            if (!criteria.targetLevels().isEmpty() && !criteria.targetLevels().contains(t.level())) continue;
            StringBuilder sql = new StringBuilder("""
                    SELECT u.cod_id_encr AS id, '%s' AS level, u.mun, u.brr, u.sub, u.conj, u.geom
                    FROM %s u
                    LEFT JOIN sub s ON s.cod_id = u.sub
                    WHERE u.geom IS NOT NULL
                    """.formatted(t.level().name(), t.tableName()));
            sql.append(commonFilters(criteria, params));
            if (!criteria.clasSub().isEmpty()) {
                sql.append(" AND u.clas_sub IN (:clasSub) ");
                params.addValue("clasSub", criteria.clasSub());
            }
            if (!criteria.cnaeCodes().isEmpty()) {
                sql.append(" AND u.cnae IN (:cnaeCodes) ");
                params.addValue("cnaeCodes", criteria.cnaeCodes());
            }
            if (!criteria.bairroNames().isEmpty()) {
                if (bairroLikeMap) {
                    // mesma regra do mapa: contém o texto, sem diferenciar maiúsculas (#TG-98)
                    List<String> ors = new ArrayList<>();
                    for (int i = 0; i < criteria.bairroNames().size(); i++) {
                        ors.add("u.brr ILIKE :bairro" + i);
                        params.addValue("bairro" + i, "%" + criteria.bairroNames().get(i) + "%");
                    }
                    sql.append(" AND (").append(String.join(" OR ", ors)).append(") ");
                } else {
                    sql.append(" AND u.brr IN (:bairroNames) ");
                    params.addValue("bairroNames", criteria.bairroNames());
                }
            }
            parts.add(sql.toString());
        }
        return parts.isEmpty() ? null : String.join("\nUNION ALL\n", parts);
    }

    /** Filtros comuns a pontos e candidatos (alias {@code u}, distribuidora pela {@code sub}). */
    private String commonFilters(DecisionCriteria criteria, MapSqlParameterSource params) {
        StringBuilder sql = new StringBuilder();
        if (!criteria.distCodes().isEmpty()) {
            sql.append(" AND s.dist IN (:distCodes) ");
            params.addValue("distCodes", criteria.distCodes());
        }
        if (!criteria.munCodes().isEmpty()) {
            sql.append(" AND u.mun IN (:munCodes) ");
            params.addValue("munCodes", criteria.munCodes());
        }
        if (!criteria.conjCodes().isEmpty()) {
            sql.append(" AND u.conj IN (:conjCodes) ");
            params.addValue("conjCodes", criteria.conjCodes());
        }
        if (!criteria.subCodes().isEmpty()) {
            sql.append(" AND u.sub IN (:subCodes) ");
            params.addValue("subCodes", criteria.subCodes());
        }
        if (criteria.hasPolygon()) {
            sql.append("""
                     AND ST_Intersects(u.geom, ST_Transform(
                        (SELECT ST_Union(d.geom) FROM ST_Dump(ST_GeomFromGeoJSON(:polygonGeojson)) d), 4674))
                    """);
            params.addValue("polygonGeojson", criteria.polygonGeojson());
        }
        return sql.toString();
    }

    private record TargetTable(String tableName, VoltageLevel level) {
    }
}
