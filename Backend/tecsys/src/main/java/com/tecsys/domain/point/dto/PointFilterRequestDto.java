package com.tecsys.domain.point.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.AssertTrue;
import java.util.List;

public record PointFilterRequestDto(
        @JsonProperty("dist_codes") List<String> distCodes,
        @JsonProperty("mun_codes") List<String> munCodes,
        @JsonProperty("conj_codes") List<String> conjCodes,
        @JsonProperty("sub_codes") List<String> subCodes,

        // Área de análise (Polygon ou MultiPolygon desenhado, GeoJSON em texto, WGS84).
        // É o campo que o motor usa.
        @JsonProperty("polygon_geojson") String polygonGeojson,

        // Retângulo da tela visível no mapa. Só limita o que é desenhado;
        // não faz parte da área de análise.
        @JsonProperty("viewport_geojson") String viewportGeojson,

        @JsonProperty("target_layers") List<String> targetLayers,
        @JsonProperty("clas_sub") List<String> clasSub,
        @JsonProperty("cnae_codes") List<String> cnaeCodes,
        @JsonProperty("bairro_names") List<String> bairroNames,

        @JsonProperty("count_only") Boolean countOnly,

        // Zoom afastado: em vez dos pontos, devolve um ponto por célula de
        // uma grade com este tamanho (em graus), com a contagem da célula.
        @JsonProperty("cluster_cell") Double clusterCell,

        // Máximo de pontos individuais devolvidos (o mapa não desenha mais
        // que isso). total_points continua sendo o total real.
        @JsonProperty("limit") Integer limit
) {
    @AssertTrue(message = "Falta de Parâmetros Iniciais: É obrigatório informar Cidade (mun_codes) e Distribuidora (dist_codes) na Etapa 1, ou ao menos um delimitador espacial.")
    public boolean isGroupAValid() {
        return (distCodes != null && !distCodes.isEmpty()) ||
                (munCodes != null && !munCodes.isEmpty()) ||
                (conjCodes != null && !conjCodes.isEmpty()) ||
                (subCodes != null && !subCodes.isEmpty()) ||
                (polygonGeojson != null && !polygonGeojson.isBlank());
    }
}
