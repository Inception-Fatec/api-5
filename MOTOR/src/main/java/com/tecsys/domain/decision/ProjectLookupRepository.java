package com.tecsys.domain.decision;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.GatewayProfileValues;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Repository
public class ProjectLookupRepository {

    private static final List<VoltageLevel> TODOS_OS_NIVEIS =
            List.of(VoltageLevel.ALTO, VoltageLevel.MEDIO, VoltageLevel.BAIXO);

    private static final Logger log = LoggerFactory.getLogger(ProjectLookupRepository.class);

    private final NamedParameterJdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public ProjectLookupRepository(NamedParameterJdbcTemplate jdbcTemplate,
                                   ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    public DecisionCriteria findCriteriaByProjectId(long projectId) {
        String sql = """
                SELECT p.dist_code, ph.filter_params::text AS filter_params
                FROM projects p
                JOIN project_history ph ON ph.project_id = p.id
                WHERE p.id = :projectId
                ORDER BY ph.created_at DESC, ph.id DESC
                LIMIT 1
                """;

        return jdbcTemplate.queryForObject(sql,
                new MapSqlParameterSource("projectId", projectId),
                (rs, rowNum) -> {
                    String distCode = rs.getString("dist_code");
                    JsonNode fp = parse(rs.getString("filter_params"));

                    List<String> distCodes =
                            (distCode != null && !distCode.isBlank()) ? List.of(distCode) : List.of();

                    return new DecisionCriteria(
                            distCodes,
                            strings(fp, "mun_codes"),
                            strings(fp, "conj_codes"),
                            strings(fp, "sub_codes"),
                            polygon(fp),
                            levels(fp),
                            strings(fp, "clas_sub"),
                            strings(fp, "cnae_codes"),
                            strings(fp, "bairro_names"),
                            // ausente (projeto antigo) = papéis padrão
                            strings(fp, "coverage_layers"),
                            strings(fp, "candidate_layers")
                    );
                });
    }

    /**
     * Perfil de gateway da última versão do projeto (#TG-150). Vazio quando a versão
     * não tem {@code gateway_profile_id} (projeto antigo) ou o perfil não existe:
     * aí o motor usa a própria configuração, como antes.
     */
    public Optional<GatewayProfileValues> findGatewayProfile(long projectId) {
        String sql = """
                WITH ultima AS (
                    SELECT ph.filter_params ->> 'gateway_profile_id' AS perfil
                    FROM project_history ph
                    WHERE ph.project_id = :projectId
                    ORDER BY ph.created_at DESC, ph.id DESC
                    LIMIT 1
                )
                SELECT gp.id, gp.name, gp.frequency_mhz, gp.tx_power_dbm, gp.antenna_gain_dbi,
                       gp.rx_sensitivity_dbm, gp.antenna_height_m, gp.sensor_height_m
                FROM ultima u
                JOIN gateway_profiles gp ON u.perfil ~ '^[0-9]+$' AND gp.id = u.perfil::bigint
                """;
        try {
            List<GatewayProfileValues> perfis = jdbcTemplate.query(sql,
                    new MapSqlParameterSource("projectId", projectId),
                    (rs, rowNum) -> new GatewayProfileValues(
                            rs.getLong("id"),
                            rs.getString("name"),
                            rs.getDouble("frequency_mhz"),
                            rs.getDouble("tx_power_dbm"),
                            rs.getDouble("antenna_gain_dbi"),
                            rs.getDouble("rx_sensitivity_dbm"),
                            rs.getDouble("antenna_height_m"),
                            rs.getDouble("sensor_height_m")));
            return perfis.stream().findFirst();
        } catch (DataAccessException e) {
            // Banco sem a tabela/colunas de perfil (migrations antigas): segue com a configuração.
            log.warn("Projeto {}: não foi possível ler o perfil de gateway ({}); usando a configuração do motor.",
                    projectId, e.getMostSpecificCause().getMessage());
            return Optional.empty();
        }
    }

    private JsonNode parse(String json) {
        if (json == null || json.isBlank()) return objectMapper.createObjectNode();
        try {
            return objectMapper.readTree(json);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("filter_params inválido no projeto.", e);
        }
    }

    private static List<String> strings(JsonNode fp, String key) {
        JsonNode node = fp.get(key);
        if (node == null || !node.isArray()) return List.of();
        List<String> out = new ArrayList<>();
        node.forEach(v -> {
            if (!v.isNull() && !v.asText().isBlank()) out.add(v.asText());
        });
        return out;
    }

    // O front manda o polígono como objeto JSON; o motor espera String.
    private static String polygon(JsonNode fp) {
        JsonNode node = fp.get("polygon_geojson");
        if (node == null || node.isNull()) return null;
        String s = node.isTextual() ? node.asText() : node.toString();
        return s.isBlank() ? null : s;
    }

    // Front: "all", "alto", "medio", "baixo". Motor: enum em maiúsculas.
    private static List<VoltageLevel> levels(JsonNode fp) {
        List<String> raw = strings(fp, "target_layers");
        if (raw.isEmpty() || raw.stream().anyMatch(v -> v.equalsIgnoreCase("all"))) {
            return TODOS_OS_NIVEIS;
        }
        List<VoltageLevel> out = new ArrayList<>();
        for (String v : raw) {
            try {
                out.add(VoltageLevel.valueOf(v.toUpperCase()));
            } catch (IllegalArgumentException ignored) {
                // valor desconhecido: ignora
            }
        }
        return out.isEmpty() ? TODOS_OS_NIVEIS : out;
    }
}