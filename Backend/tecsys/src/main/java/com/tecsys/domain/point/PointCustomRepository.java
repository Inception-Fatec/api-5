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

            // clas_sub / cnae / brr só existem nas 3 tabelas de
            // consumidor (ucat_pj, ucmt_pj, ucbt) — as tabelas de
            // rede/estrutura (sub, untrat, untrmt, ssdat, ssdmt,
            // ssdbt) não têm essas colunas, então só aplica quando
            // meta.hasAttributes for true (senão o SQL quebraria
            // referenciando coluna inexistente).
            if (meta.hasAttributes) {
                if (request.clasSub() != null && !request.clasSub().isEmpty()) {
                    subQuery.append(" AND clas_sub IN (:clasSub) ");
                    params.addValue("clasSub", request.clasSub());
                }
                if (request.cnaeCodes() != null && !request.cnaeCodes().isEmpty()) {
                    subQuery.append(" AND cnae IN (:cnaeCodes) ");
                    params.addValue("cnaeCodes", request.cnaeCodes());
                }
                if (request.bairroNames() != null && !request.bairroNames().isEmpty()) {
                    subQuery.append(" AND brr IN (:bairroNames) ");
                    params.addValue("bairroNames", request.bairroNames());
                }
            }

            if (request.polygonGeojson() != null && !request.polygonGeojson().isBlank()) {
                subQuery.append(" AND ST_Intersects(geom, ST_Transform(ST_GeomFromGeoJSON(:polygon), 4674)) ");
                params.addValue("polygon", request.polygonGeojson());
            }

            unionQueries.add(subQuery.toString());
        }

        if (unionQueries.isEmpty()) {
            return new PointFilterResponseDto(0L, emptyFeatureCollection());
        }

        boolean countOnly = Boolean.TRUE.equals(request.countOnly());
        String unionSql = String.join(" UNION ALL ", unionQueries);

        // count_only=true: só interessa "tem ponto ou não" (ex:
        // validação de cidade no seletor do front) — pula de vez o
        // ST_AsGeoJSON/jsonb_agg, que é a parte cara aqui (serializar
        // geometria de cada ponto individualmente). Um SELECT COUNT
        // sobre a mesma UNION é ordens de magnitude mais rápido com
        // dezenas de milhares de linhas.
        if (countOnly) {
            String countSql = """
                SELECT COUNT(*) AS total_points FROM (
                    %s
                ) f;
            """.formatted(unionSql);

            Long total = jdbcTemplate.queryForObject(countSql, params, Long.class);
            return new PointFilterResponseDto(total == null ? 0L : total, emptyFeatureCollection());
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
        """.formatted(unionSql);

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

    private com.fasterxml.jackson.databind.JsonNode emptyFeatureCollection() {
        // Mesmo formato do caminho "cheio" (objeto FeatureCollection),
        // só com features vazio — evita que o front receba um []
        // solto onde ele sempre espera um objeto com campo "features"
        // dentro (foi exatamente essa inconsistência que quebrava a
        // validação de cidade no seletor, mesmo com total_points > 0).
        com.fasterxml.jackson.databind.node.ObjectNode empty = objectMapper.createObjectNode();
        empty.put("type", "FeatureCollection");
        empty.putArray("features");
        return empty;
    }

    private Set<TableMetadata> resolveTablesFromTensionLevels(List<String> targetLayers) {
        List<TableMetadata> allTables = List.of(
                new TableMetadata("sub", "cod_id", "SUB", false, false, false),
                new TableMetadata("ucat_pj", "cod_id_encr", "ALTO", true, true, true),
                new TableMetadata("ssdat", "cod_id", "ALTO", false, true, false),
                new TableMetadata("untrat", "cod_id", "ALTO", true, true, false),
                new TableMetadata("ucmt_pj", "cod_id_encr", "MEDIO", true, true, true),
                new TableMetadata("ssdmt", "cod_id", "MEDIO", false, true, false),
                new TableMetadata("untrmt", "cod_id", "MEDIO", true, true, false),
                new TableMetadata("ucbt", "cod_id_encr", "BAIXO", true, true, true),
                new TableMetadata("ssdbt", "cod_id", "BAIXO", false, true, false)
        );

        if (targetLayers == null || targetLayers.isEmpty() || targetLayers.contains("all")) {
            return Set.copyOf(allTables);
        }

        Set<String> upperLayers = targetLayers.stream().map(String::toUpperCase).collect(Collectors.toSet());
        return allTables.stream()
                .filter(t -> upperLayers.contains(t.layerName) || t.layerName.equals("SUB"))
                .collect(Collectors.toSet());
    }

    private record TableMetadata(String tableName, String idColumn, String layerName, boolean hasMun, boolean hasConj, boolean hasAttributes) {}
}