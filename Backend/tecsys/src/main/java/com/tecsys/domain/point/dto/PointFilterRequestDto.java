package com.tecsys.domain.point.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.AssertTrue;
import java.util.List;

public record PointFilterRequestDto(
        @JsonProperty("dist_codes") List<String> distCodes,
        @JsonProperty("mun_codes") List<String> munCodes,
        @JsonProperty("conj_codes") List<String> conjCodes,
        @JsonProperty("sub_codes") List<String> subCodes,
        @JsonProperty("polygon_geojson") String polygonGeojson,

        @JsonProperty("target_layers") List<String> targetLayers,
        @JsonProperty("clas_sub") List<String> clasSub,
        @JsonProperty("cnae_codes") List<String> cnaeCodes,
        @JsonProperty("bairro_names") List<String> bairroNames,

    
        @JsonProperty("count_only") Boolean countOnly
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