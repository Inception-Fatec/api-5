package com.tecsys.domain.point;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.point.dto.PointFilterRequestDto;
import com.tecsys.domain.point.dto.PointFilterResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Repository
@RequiredArgsConstructor
public class PointCustomRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public PointFilterResponseDto executeSpatialFilter(PointFilterRequestDto request) {
        MapSqlParameterSource params = new MapSqlParameterSource();
        List<String> unionQueries = new ArrayList<>();

        Set<TableMetadata> targetTables = resolveTablesFromTensionLevels(request.targetLayers());

        for (TableMetadata meta : targetTables) {
            StringBuilder subQuery = new StringBuilder();

            subQuery.append("SELECT '").append(meta.layerName).append("' AS layer, ")
                    .append(meta.idColumn).append(" AS id, geom FROM ").append(meta.tableName)
                    .append(" WHERE 1=1 ");

            if (request.distCodes() != null && !request.distCodes().isEmpty()) {
                if (meta.tableName.equals("sub")) {
                    subQuery.append(" AND dist IN (:distCodes) ");
                } else {
                    subQuery.append(" AND sub IN (SELECT cod_id FROM sub WHERE dist IN (:distCodes)) ");
                }
                params.addValue("distCodes", request.distCodes());
            }

            if (request.munCodes() != null && !request.munCodes().isEmpty()) {
                if (meta.hasMun) {
                    subQuery.append(" AND mun IN (:munCodes) ");
                } else {
                    switch (meta.tableName) {
                        case "ssdat":
                            subQuery.append(" AND conj IN (SELECT conj FROM untrat WHERE mun IN (:munCodes)) ");
                            break;
                        case "ssdmt":
                            subQuery.append(" AND uni_tr_at IN (SELECT cod_id FROM untrat WHERE mun IN (:munCodes)) ");
                            break;
                        case "ssdbt":
                            subQuery.append(" AND uni_tr_mt IN (SELECT cod_id FROM untrmt WHERE mun IN (:munCodes)) ");
                            break;
                        case "sub":
                            subQuery.append(" AND cod_id IN (SELECT sub FROM untrat WHERE mun IN (:munCodes)) ");
                            break;
                    }
                }
                params.addValue("munCodes", request.munCodes());
            }

            if (request.conjCodes() != null && !request.conjCodes().isEmpty() && meta.hasConj) {
                subQuery.append(" AND conj IN (:conjCodes) ");
                params.addValue("conjCodes", request.conjCodes());
            }

            if (request.subCodes() != null && !request.subCodes().isEmpty()) {
                if (meta.tableName.equals("sub")) {
                    subQuery.append(" AND cod_id IN (:subCodes) ");
                } else {
                    subQuery.append(" AND sub IN (:subCodes) ");
                }
                params.addValue("subCodes", request.subCodes());
            }

            if (request.polygonGeojson() != null && !request.polygonGeojson().isBlank()) {
                subQuery.append(" AND ST_Intersects(geom, ST_Transform(ST_GeomFromGeoJSON(:polygon), 4674)) ");
                params.addValue("polygon", request.polygonGeojson());
            }

            unionQueries.add(subQuery.toString());
        }

        if (unionQueries.isEmpty()) {
            return new PointFilterResponseDto(0L, objectMapper.createArrayNode());
        }

        String finalSql = """
            WITH filtered_points AS (
                %s
            )
            SELECT 
                (SELECT COUNT(*) FROM filtered_points) AS total_points,
                jsonb_build_object(
                    'type', 'FeatureCollection',
                    'features', COALESCE(jsonb_agg(
                        jsonb_build_object(
                            'type', 'Feature',
                            'geometry', ST_AsGeoJSON(ST_Transform(f.geom, 4326))::jsonb,
                            'properties', jsonb_build_object('id', f.id, 'layer', f.layer)
                        )
                    ), '[]'::jsonb)
                ) AS geojson_features
            FROM filtered_points f;
        """.formatted(String.join(" UNION ALL ", unionQueries));

        return jdbcTemplate.queryForObject(finalSql, params, (rs, rowNum) -> {
            try {
                Long total = rs.getLong("total_points");
                String geojsonStr = rs.getString("geojson_features");
                return new PointFilterResponseDto(total, objectMapper.readTree(geojsonStr));
            } catch (Exception e) {
                throw new RuntimeException("Falha ao serializar o retorno GeoJSON do PostGIS", e);
            }
        });
    }

    private Set<TableMetadata> resolveTablesFromTensionLevels(List<String> targetLayers) {
        List<TableMetadata> allTables = List.of(
                new TableMetadata("sub", "cod_id", "SUB", false, false),
                new TableMetadata("ucat_pj", "cod_id_encr", "ALTO", true, true),
                new TableMetadata("ssdat", "cod_id", "ALTO", false, true),
                new TableMetadata("untrat", "cod_id", "ALTO", true, true),
                new TableMetadata("ucmt_pj", "cod_id_encr", "MEDIO", true, true),
                new TableMetadata("ssdmt", "cod_id", "MEDIO", false, true),
                new TableMetadata("untrmt", "cod_id", "MEDIO", true, true),
                new TableMetadata("ucbt", "cod_id_encr", "BAIXO", true, true),
                new TableMetadata("ssdbt", "cod_id", "BAIXO", false, true)
        );

        if (targetLayers == null || targetLayers.isEmpty() || targetLayers.contains("all")) {
            return Set.copyOf(allTables);
        }

        Set<String> upperLayers = targetLayers.stream().map(String::toUpperCase).collect(Collectors.toSet());
        return allTables.stream()
                .filter(t -> upperLayers.contains(t.layerName) || t.layerName.equals("SUB"))
                .collect(Collectors.toSet());
    }

    private record TableMetadata(String tableName, String idColumn, String layerName, boolean hasMun, boolean hasConj) {}
}