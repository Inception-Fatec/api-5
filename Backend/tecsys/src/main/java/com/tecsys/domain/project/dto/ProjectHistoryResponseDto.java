package com.tecsys.domain.project.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonRawValue;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.Instant;

/**
 * Uma versão do projeto (linha de project_history), para o histórico (#TG-85)
 * e para o mapa abrir o projeto com a área e os filtros salvos (#TG-86).
 */
public record ProjectHistoryResponseDto(
        Long id,

        @JsonProperty("created_at")
        @JsonFormat(pattern = "dd/MM/yyyy HH:mm:ss", timezone = "America/Sao_Paulo")
        Instant createdAt,

        @JsonProperty("filter_params")
        JsonNode filterParams,

        // perfil de gateway usado na versão; null enquanto o filter_params não trouxer
        @JsonProperty("gateway_profile")
        String gatewayProfile,

        // área desenhada como objeto GeoJSON (o banco já devolve via ST_AsGeoJSON)
        @JsonProperty("polygon")
        @JsonRawValue
        String polygonGeojson
) {
    /** Perfil de gateway salvo no filter_params ("gateway_profile"), ou null. */
    public static String perfilDe(JsonNode filterParams) {
        if (filterParams == null) return null;
        JsonNode perfil = filterParams.path("gateway_profile");
        if (perfil.isMissingNode() || perfil.isNull()) return null;
        String texto = perfil.isTextual() ? perfil.asText().trim() : perfil.toString();
        return texto.isEmpty() ? null : texto;
    }
}
