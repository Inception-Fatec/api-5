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

    private static final List<String> COLUNAS_EXTRAS = List.of(
            "mun", "brr", "sub", "conj", "clas_sub", "cnae",
            "car_inst", "dem_cont", "tip_sist", "are_loc", "uni_tr_mt",
            "nome", "dist"
    );

    public PointFilterResponseDto executeSpatialFilter(PointFilterRequestDto request) {
        MapSqlParameterSource params = new MapSqlParameterSource();
        List<String> unionQueries = new ArrayList<>();

        Set<TableMetadata> targetTables = resolveTablesFromTensionLevels(request.targetLayers());


        boolean temFiltroDeAtributo = (request.clasSub() != null && !request.clasSub().isEmpty())
                || (request.cnaeCodes() != null && !request.cnaeCodes().isEmpty())
                || (request.bairroNames() != null && !request.bairroNames().isEmpty());
        if (temFiltroDeAtributo) {
            targetTables = targetTables.stream().filter(t -> t.hasAttributes).collect(Collectors.toSet());
        }

        for (TableMetadata meta : targetTables) {
            StringBuilder subQuery = new StringBuilder();
            String suf = "_" + meta.tableName;

            subQuery.append("SELECT '").append(meta.layerName).append("' AS layer, ")
                    .append(meta.idColumn).append(" AS id, ");
            for (String coluna : COLUNAS_EXTRAS) {
                if (meta.colunasExtras.contains(coluna)) {
                    subQuery.append(coluna).append("::text AS extra_").append(coluna).append(", ");
                } else {
                    subQuery.append("NULL::text AS extra_").append(coluna).append(", ");
                }
            }
            subQuery.append("geom FROM ").append(meta.tableName).append(" WHERE 1=1 ");

            if (request.distCodes() != null && !request.distCodes().isEmpty()) {
                if (meta.tableName.equals("sub")) {
                    subQuery.append(" AND dist IN (:distCodes").append(suf).append(") ");
                } else {
                    subQuery.append(" AND sub IN (SELECT cod_id FROM sub WHERE dist IN (:distCodes").append(suf).append(")) ");
                }
                params.addValue("distCodes" + suf, request.distCodes());
            }

            if (request.munCodes() != null && !request.munCodes().isEmpty()) {
                if (meta.hasMun) {
                    subQuery.append(" AND mun IN (:munCodes").append(suf).append(") ");
                } else {
                    switch (meta.tableName) {
                        case "ssdat":
                            subQuery.append(" AND conj IN (SELECT conj FROM untrat WHERE mun IN (:munCodes").append(suf).append(")) ");
                            break;
                        case "ssdmt":
                            subQuery.append(" AND uni_tr_at IN (SELECT cod_id FROM untrat WHERE mun IN (:munCodes").append(suf).append(")) ");
                            break;
                        case "ssdbt":
                            subQuery.append(" AND uni_tr_mt IN (SELECT cod_id FROM untrmt WHERE mun IN (:munCodes").append(suf).append(")) ");
                            break;
                        case "sub":
                            subQuery.append(" AND cod_id IN (SELECT sub FROM untrat WHERE mun IN (:munCodes").append(suf).append(")) ");
                            break;
                    }
                }
                params.addValue("munCodes" + suf, request.munCodes());
            }

            if (request.conjCodes() != null && !request.conjCodes().isEmpty() && meta.hasConj) {
                subQuery.append(" AND conj IN (:conjCodes").append(suf).append(") ");
                params.addValue("conjCodes" + suf, request.conjCodes());
            }

            if (request.subCodes() != null && !request.subCodes().isEmpty()) {
                if (meta.tableName.equals("sub")) {
                    subQuery.append(" AND cod_id IN (:subCodes").append(suf).append(") ");
                } else {
                    subQuery.append(" AND sub IN (:subCodes").append(suf).append(") ");
                }
                params.addValue("subCodes" + suf, request.subCodes());
            }

            if (meta.hasAttributes) {
                if (request.clasSub() != null && !request.clasSub().isEmpty()) {
                    subQuery.append(" AND clas_sub IN (:clasSub").append(suf).append(") ");
                    params.addValue("clasSub" + suf, request.clasSub());
                }
                if (request.cnaeCodes() != null && !request.cnaeCodes().isEmpty()) {
                    subQuery.append(" AND cnae IN (:cnaeCodes").append(suf).append(") ");
                    params.addValue("cnaeCodes" + suf, request.cnaeCodes());
                }
                if (request.bairroNames() != null && !request.bairroNames().isEmpty()) {
                    List<String> condicoesBairro = new ArrayList<>();
                    for (int i = 0; i < request.bairroNames().size(); i++) {
                        String nomeParametro = "bairro" + i + suf;
                        condicoesBairro.add("brr ILIKE :" + nomeParametro);
                        params.addValue(nomeParametro, "%" + request.bairroNames().get(i) + "%");
                    }
                    subQuery.append(" AND (").append(String.join(" OR ", condicoesBairro)).append(") ");
                }
            }

            if (request.polygonGeojson() != null && !request.polygonGeojson().isBlank()) {
                subQuery.append(" AND ST_Intersects(geom, ST_Transform(")
                        .append("(SELECT ST_Union(d.geom) FROM ST_Dump(ST_GeomFromGeoJSON(:polygon")
                        .append(suf).append(")) d), 4674)) ");
                params.addValue("polygon" + suf, request.polygonGeojson());
            }

            // Tela visível: só limita o que vai pro mapa.
            if (request.viewportGeojson() != null && !request.viewportGeojson().isBlank()) {
                subQuery.append(" AND ST_Intersects(geom, ST_Transform(ST_GeomFromGeoJSON(:viewport")
                        .append(suf).append("), 4674)) ");
                params.addValue("viewport" + suf, request.viewportGeojson());
            }

            unionQueries.add(subQuery.toString());
        }

        if (unionQueries.isEmpty()) {
            return new PointFilterResponseDto(0L, emptyFeatureCollection());
        }

        boolean countOnly = Boolean.TRUE.equals(request.countOnly());
        String unionSql = String.join(" UNION ALL ", unionQueries);


        if (countOnly) {
            String countSql = """
                SELECT COUNT(*) AS total_points FROM (
                    %s
                ) f;
            """.formatted(unionSql);

            Long total = jdbcTemplate.queryForObject(countSql, params, Long.class);
            return new PointFilterResponseDto(total == null ? 0L : total, emptyFeatureCollection());
        }

        StringBuilder propriedadesSql = new StringBuilder("jsonb_build_object('id', f.id, 'layer', f.layer");
        for (String coluna : COLUNAS_EXTRAS) {
            propriedadesSql.append(", '").append(coluna).append("', f.extra_").append(coluna);
        }
        propriedadesSql.append(")");

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
                            'properties', %s
                        )
                    ), '[]'::jsonb)
                ) AS geojson_features
            FROM filtered_points f;
        """.formatted(unionSql, propriedadesSql);

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
        com.fasterxml.jackson.databind.node.ObjectNode empty = objectMapper.createObjectNode();
        empty.put("type", "FeatureCollection");
        empty.putArray("features");
        return empty;
    }

    public List<String> buscarBairros(List<String> munCodes, String q) {
        if (munCodes == null || munCodes.isEmpty()) return List.of();

        MapSqlParameterSource params = new MapSqlParameterSource();
        params.addValue("munCodesUcbt", munCodes);
        params.addValue("munCodesUcmt", munCodes);
        params.addValue("munCodesUcat", munCodes);
        params.addValue("qUcbt", "%" + (q == null ? "" : q) + "%");
        params.addValue("qUcmt", "%" + (q == null ? "" : q) + "%");
        params.addValue("qUcat", "%" + (q == null ? "" : q) + "%");

        String sql = """
            SELECT DISTINCT brr FROM (
                SELECT brr FROM ucbt WHERE mun IN (:munCodesUcbt) AND brr ILIKE :qUcbt
                UNION
                SELECT brr FROM ucmt_pj WHERE mun IN (:munCodesUcmt) AND brr ILIKE :qUcmt
                UNION
                SELECT brr FROM ucat_pj WHERE mun IN (:munCodesUcat) AND brr ILIKE :qUcat
            ) todos
            ORDER BY brr
            LIMIT 20
        """;

        return jdbcTemplate.queryForList(sql, params, String.class);
    }

    private Set<TableMetadata> resolveTablesFromTensionLevels(List<String> targetLayers) {
        List<TableMetadata> allTables = List.of(
                new TableMetadata("sub", "cod_id", "SUB", false, false, false, Set.of("nome", "dist")),
                new TableMetadata("ucat_pj", "cod_id_encr", "ALTO", true, true, true,
                        Set.of("mun", "brr", "sub", "conj", "clas_sub", "cnae", "car_inst", "dem_cont", "tip_sist", "are_loc")),
                new TableMetadata("ssdat", "cod_id", "ALTO", false, true, false, Set.of()),
                new TableMetadata("untrat", "cod_id", "ALTO", true, true, false, Set.of()),
                new TableMetadata("ucmt_pj", "cod_id_encr", "MEDIO", true, true, true,
                        Set.of("mun", "brr", "sub", "conj", "clas_sub", "cnae", "car_inst", "dem_cont", "tip_sist", "are_loc")),
                new TableMetadata("ssdmt", "cod_id", "MEDIO", false, true, false, Set.of()),
                new TableMetadata("untrmt", "cod_id", "MEDIO", true, true, false, Set.of()),
                new TableMetadata("ucbt", "cod_id_encr", "BAIXO", true, true, true,
                        Set.of("mun", "brr", "sub", "conj", "clas_sub", "cnae", "car_inst", "tip_sist", "are_loc", "uni_tr_mt")),
                new TableMetadata("ssdbt", "cod_id", "BAIXO", false, true, false, Set.of())
        );

        if (targetLayers == null || targetLayers.isEmpty() || targetLayers.contains("all")) {
            return Set.copyOf(allTables);
        }

        Set<String> upperLayers = targetLayers.stream().map(String::toUpperCase).collect(Collectors.toSet());
        return allTables.stream()
                .filter(t -> upperLayers.contains(t.layerName) || t.layerName.equals("SUB"))
                .collect(Collectors.toSet());
    }

    private record TableMetadata(
            String tableName, String idColumn, String layerName,
            boolean hasMun, boolean hasConj, boolean hasAttributes,
            Set<String> colunasExtras
    ) {}
}