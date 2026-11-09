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

    private static final int MAX_POINTS_LIMIT = 20000;

    private static final List<String> COLUNAS_EXTRAS = List.of(
            "mun", "brr", "sub", "conj", "clas_sub", "cnae",
            "car_inst", "dem_cont", "tip_sist", "are_loc", "uni_tr_mt",
            "uni_tr_at", "nome", "dist");

    public PointFilterResponseDto executeSpatialFilter(PointFilterRequestDto request) {
        MapSqlParameterSource params = new MapSqlParameterSource();
        List<String> unionQueries = new ArrayList<>();

        List<Consulta> consultas = resolverConsultas(request);

        boolean temFiltroDeAtributo = (request.clasSub() != null && !request.clasSub().isEmpty())
                || (request.cnaeCodes() != null && !request.cnaeCodes().isEmpty())
                || (request.bairroNames() != null && !request.bairroNames().isEmpty());

        // Rede e subestação são só desenho: só entram quando o mapa mostra os
        // elementos um a um (zoom de perto). Nas bolhas e na contagem elas
        // ficam de fora — as bolhas contam só pontos a cobrir, igual ao topo
        // e ao relatório, e a consulta fica mais leve. Com classe, CNAE ou
        // bairro (que só existem nos consumidores) a rede também some.
        boolean countOnly = Boolean.TRUE.equals(request.countOnly());
        Double cell = request.clusterCell();
        boolean agrupado = !countOnly && cell != null && cell > 0;
        if (countOnly || agrupado || temFiltroDeAtributo) {
            consultas = consultas.stream()
                    .filter(c -> !c.cat().equals(REDE))
                    .toList();
        }

        for (Consulta consulta : consultas) {
            TableMetadata meta = consulta.meta();
            StringBuilder subQuery = new StringBuilder();
            // Uma camada pode entrar duas vezes (ponto e candidato): sufixo por papel.
            String suf = "_" + meta.tableName + "_" + consulta.cat();

            subQuery.append("SELECT '").append(meta.layerName).append("' AS layer, ")
                    .append("'").append(consulta.cat()).append("' AS cat, ")
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
                    subQuery.append(" AND sub IN (SELECT cod_id FROM sub WHERE dist IN (:distCodes").append(suf)
                            .append(")) ");
                }
                params.addValue("distCodes" + suf, request.distCodes());
            }

            if (request.munCodes() != null && !request.munCodes().isEmpty()) {
                if (meta.hasMun) {
                    subQuery.append(" AND mun IN (:munCodes").append(suf).append(") ");
                } else {
                    switch (meta.tableName) {
                        case "ssdat":
                            subQuery.append(" AND conj IN (SELECT conj FROM untrat WHERE mun IN (:munCodes").append(suf)
                                    .append(")) ");
                            break;
                        case "ssdmt":
                            subQuery.append(" AND uni_tr_at IN (SELECT cod_id FROM untrat WHERE mun IN (:munCodes")
                                    .append(suf).append(")) ");
                            break;
                        case "ssdbt":
                            subQuery.append(" AND uni_tr_mt IN (SELECT cod_id FROM untrmt WHERE mun IN (:munCodes")
                                    .append(suf).append(")) ");
                            break;
                        case "sub":
                            subQuery.append(" AND cod_id IN (SELECT sub FROM untrat WHERE mun IN (:munCodes")
                                    .append(suf).append(")) ");
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

            // Classe, CNAE e bairro filtram só os pontos a cobrir: os
            // candidatos não dependem deles (igual ao motor).
            if (meta.hasAttributes && consulta.cat().equals(PONTO)) {
                if (request.clasSub() != null && !request.clasSub().isEmpty()) {
                    subQuery.append(" AND clas_sub IN (:clasSub").append(suf).append(") ");
                    params.addValue("clasSub" + suf, request.clasSub());
                }
                if (request.cnaeCodes() != null && !request.cnaeCodes().isEmpty()) {
                    subQuery.append(" AND cnae IN (:cnaeCodes").append(suf).append(") ");
                    params.addValue("cnaeCodes" + suf, request.cnaeCodes());
                }
                if (request.bairroNames() != null && !request.bairroNames().isEmpty()) {
                    subQuery.append(" AND brr IN (:bairroNames").append(suf).append(") ");
                    params.addValue("bairroNames" + suf, request.bairroNames());
                }
            }

            if (request.polygonGeojson() != null && !request.polygonGeojson().isBlank()) {
                subQuery.append(" AND ST_Intersects(geom, ST_Transform(")
                        .append("(SELECT ST_Union(d.geom) FROM ST_Dump(ST_GeomFromGeoJSON(:polygon")
                        .append(suf).append(")) d), 4674)) ");
                params.addValue("polygon" + suf, request.polygonGeojson());
            }

            if (request.viewportGeojson() != null && !request.viewportGeojson().isBlank()) {
                subQuery.append(" AND ST_Intersects(geom, ST_Transform(ST_GeomFromGeoJSON(:viewport")
                        .append(suf).append("), 4674)) ");
                params.addValue("viewport" + suf, request.viewportGeojson());
            }

            unionQueries.add(subQuery.toString());
        }

        if (unionQueries.isEmpty()) {
            return new PointFilterResponseDto(0L, 0L, 0L, emptyFeatureCollection());
        }

        String unionSql = String.join(" UNION ALL ", unionQueries);

        if (agrupado) {
            String clusterSql = """
                        WITH filtered_points AS (
                            %s
                        ), totais AS (
                            SELECT count(*) FILTER (WHERE f.cat = 'ponto') AS np,
                                   count(*) FILTER (WHERE f.cat = 'candidato') AS nc
                            FROM filtered_points f
                        ), celulas AS (
                            -- Cada bolha conta só pontos a cobrir (consumidores).
                            SELECT count(*) AS n,
                                   ST_Transform(ST_Centroid(ST_Collect(ST_PointOnSurface(f.geom))), 4326) AS c
                            FROM filtered_points f
                            WHERE f.cat = 'ponto'
                            GROUP BY ST_SnapToGrid(ST_PointOnSurface(f.geom), :clusterCell)
                        )
                        SELECT (SELECT np FROM totais) AS total_points,
                               (SELECT nc FROM totais) AS total_candidates,
                               0 AS total_network,
                               jsonb_build_object(
                                   'type', 'FeatureCollection',
                                   'features', COALESCE(jsonb_agg(
                                       jsonb_build_object(
                                           'type', 'Feature',
                                           'geometry', ST_AsGeoJSON(c, 6)::jsonb,
                                           'properties', jsonb_build_object('count', n, 'cluster', true)
                                       )
                                   ), '[]'::jsonb)
                               ) AS geojson_features
                        FROM celulas;
                    """.formatted(unionSql);
            params.addValue("clusterCell", cell);

            return jdbcTemplate.queryForObject(clusterSql, params, (rs, rowNum) -> {
                try {
                    String geojsonStr = rs.getString("geojson_features");
                    return new PointFilterResponseDto(
                            rs.getLong("total_points"),
                            rs.getLong("total_candidates"),
                            rs.getLong("total_network"),
                            objectMapper.readTree(geojsonStr));
                } catch (Exception e) {
                    throw new RuntimeException("Falha ao serializar o agrupamento do PostGIS", e);
                }
            });
        }

        if (countOnly) {
            String countSql = """
                        SELECT COUNT(*) FILTER (WHERE f.cat = 'ponto') AS total_points,
                               COUNT(*) FILTER (WHERE f.cat = 'candidato') AS total_candidates,
                               COUNT(*) FILTER (WHERE f.cat = 'rede') AS total_network
                        FROM (
                            %s
                        ) f;
                    """.formatted(unionSql);

            return jdbcTemplate.queryForObject(countSql, params, (rs, rowNum) -> new PointFilterResponseDto(
                    rs.getLong("total_points"),
                    rs.getLong("total_candidates"),
                    rs.getLong("total_network"),
                    emptyFeatureCollection()));
        }

        StringBuilder propriedadesSql = new StringBuilder(
                "jsonb_build_object('id', f.id, 'layer', f.layer, 'categoria', f.cat");
        for (String coluna : COLUNAS_EXTRAS) {
            propriedadesSql.append(", '").append(coluna).append("', f.extra_").append(coluna);
        }
        propriedadesSql.append(")");

        int limitToApply = (request.limit() != null && request.limit() > 0)
                ? Math.min(request.limit(), MAX_POINTS_LIMIT)
                : MAX_POINTS_LIMIT;

        String limitSql = " LIMIT :limit";
        params.addValue("limit", limitToApply);

        String finalSql = """
                    WITH filtered_points AS (
                        %s
                    )
                    SELECT
                        (SELECT COUNT(*) FROM filtered_points WHERE cat = 'ponto') AS total_points,
                        (SELECT COUNT(*) FROM filtered_points WHERE cat = 'candidato') AS total_candidates,
                        (SELECT COUNT(*) FROM filtered_points WHERE cat = 'rede') AS total_network,
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
                    FROM (
                        -- No limite de elementos, consumidores primeiro, depois
                        -- candidatos e por último a rede (que é só desenho).
                        SELECT * FROM filtered_points
                        ORDER BY CASE cat WHEN 'ponto' THEN 0 WHEN 'candidato' THEN 1 ELSE 2 END%s
                    ) f;
                """.formatted(unionSql, propriedadesSql, limitSql);

        return jdbcTemplate.queryForObject(finalSql, params, (rs, rowNum) -> {
            try {
                String geojsonStr = rs.getString("geojson_features");
                return new PointFilterResponseDto(
                        rs.getLong("total_points"),
                        rs.getLong("total_candidates"),
                        rs.getLong("total_network"),
                        objectMapper.readTree(geojsonStr));
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
        if (munCodes == null || munCodes.isEmpty())
            return List.of();

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

    static final String PONTO = "ponto";
    static final String CANDIDATO = "candidato";
    static final String REDE = "rede";

    /** Camadas que podem ser pontos a cobrir (consumidores). */
    static final List<String> CAMADAS_COBERTURA = List.of("ucat_pj", "ucmt_pj", "ucbt");
    /** Camadas que podem ser candidatas a gateway (transformadores e consumidores). */
    static final List<String> CAMADAS_CANDIDATAS = List.of("untrmt", "untrat", "ucat_pj", "ucmt_pj", "ucbt");
    static final List<String> PADRAO_COBERTURA = CAMADAS_COBERTURA;
    static final List<String> PADRAO_CANDIDATOS = List.of("untrmt", "untrat");

    /** Uma subconsulta: a camada e o papel com que ela entra (ponto, candidato ou rede). */
    record Consulta(TableMetadata meta, String cat) {
    }

    /** Camadas válidas pedidas para um papel; nada válido = padrão. */
    static Set<String> camadas(List<String> pedidas, List<String> permitidas, List<String> padrao) {
        if (pedidas != null) {
            Set<String> validas = pedidas.stream()
                    .filter(c -> c != null)
                    .map(c -> c.trim().toLowerCase())
                    .filter(permitidas::contains)
                    .collect(Collectors.toSet());
            if (!validas.isEmpty()) return validas;
        }
        return Set.copyOf(padrao);
    }

    /**
     * O que entra no mapa e em que papel (#TG-92):
     * <ul>
     *   <li>ponto a cobrir: camada de {@code coverage_layers} no nível de tensão escolhido;</li>
     *   <li>candidato: camada de {@code candidate_layers}, independente da tensão (igual ao motor);</li>
     *   <li>rede: trechos, subestação e transformadores que não são candidatos (só desenho).</li>
     * </ul>
     * Consumidor sem papel não aparece. Uma camada nos dois papéis entra duas vezes.
     */
    static List<Consulta> resolverConsultas(PointFilterRequestDto request) {
        Set<String> cobertura = camadas(request.coverageLayers(), CAMADAS_COBERTURA, PADRAO_COBERTURA);
        Set<String> candidatas = camadas(request.candidateLayers(), CAMADAS_CANDIDATAS, PADRAO_CANDIDATOS);
        Set<TableMetadata> noNivel = resolveTablesFromTensionLevels(request.targetLayers());

        List<Consulta> consultas = new ArrayList<>();
        for (TableMetadata t : TODAS_AS_TABELAS) {
            boolean nivelOk = noNivel.contains(t);
            if (t.hasAttributes) {
                if (cobertura.contains(t.tableName) && nivelOk) consultas.add(new Consulta(t, PONTO));
                if (candidatas.contains(t.tableName)) consultas.add(new Consulta(t, CANDIDATO));
            } else if (candidatas.contains(t.tableName)) {
                consultas.add(new Consulta(t, CANDIDATO));
            } else if (nivelOk) {
                consultas.add(new Consulta(t, REDE));
            }
        }
        return consultas;
    }

    private static final List<TableMetadata> TODAS_AS_TABELAS = List.of(
                new TableMetadata("sub", "cod_id", "SUB", false, false, false, Set.of("nome", "dist")),
                new TableMetadata("ucat_pj", "cod_id_encr", "ALTO", true, true, true,
                        Set.of("mun", "brr", "sub", "conj", "clas_sub", "cnae", "car_inst", "dem_cont", "tip_sist",
                                "are_loc")),
                new TableMetadata("ssdat", "cod_id", "ALTO", false, true, false, Set.of("sub", "conj")),
                new TableMetadata("untrat", "cod_id", "ALTO", true, true, false, Set.of("mun", "sub", "conj")),
                new TableMetadata("ucmt_pj", "cod_id_encr", "MEDIO", true, true, true,
                        Set.of("mun", "brr", "sub", "conj", "clas_sub", "cnae", "car_inst", "dem_cont", "tip_sist",
                                "are_loc")),
                new TableMetadata("ssdmt", "cod_id", "MEDIO", false, true, false, Set.of("sub", "conj", "uni_tr_at")),
                new TableMetadata("untrmt", "cod_id", "MEDIO", true, true, false, Set.of("mun", "sub", "conj")),
                new TableMetadata("ucbt", "cod_id_encr", "BAIXO", true, true, true,
                        Set.of("mun", "brr", "sub", "conj", "clas_sub", "cnae", "car_inst", "tip_sist", "are_loc",
                                "uni_tr_mt", "qtd_consumidores")),
                new TableMetadata("ssdbt", "cod_id", "BAIXO", false, true, false, Set.of("sub", "conj", "uni_tr_mt")));

    /** Tabelas no nível de tensão pedido (a subestação sempre entra). */
    private static Set<TableMetadata> resolveTablesFromTensionLevels(List<String> targetLayers) {
        List<TableMetadata> allTables = TODAS_AS_TABELAS;

        if (targetLayers == null || targetLayers.isEmpty() || targetLayers.contains("all")) {
            return Set.copyOf(allTables);
        }

        Set<String> upperLayers = targetLayers.stream().map(String::toUpperCase).collect(Collectors.toSet());
        return allTables.stream()
                .filter(t -> upperLayers.contains(t.layerName) || t.layerName.equals("SUB"))
                .collect(Collectors.toSet());
    }

    record TableMetadata(
            String tableName, String idColumn, String layerName,
            boolean hasMun, boolean hasConj, boolean hasAttributes,
            Set<String> colunasExtras) {
    }
}