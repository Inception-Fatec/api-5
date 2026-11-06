package com.tecsys.domain.decision.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record DecisionSummaryResponseDto(

        @JsonProperty("total_points")
        int totalPoints,

        @JsonProperty("total_candidates")
        int totalCandidates,

        @JsonProperty("selected_gateways")
        int selectedGateways,

        @JsonProperty("covered_points")
        int coveredPoints,

        @JsonProperty("uncovered_points")
        int uncoveredPoints,

        @JsonProperty("coverage_percentage")
        double coveragePercentage,

        // raio de busca usado no cálculo: alcance fixo ou o menor entre orçamento de enlace e horizonte
        @JsonProperty("gateway_range_m")
        int gatewayRangeMeters,

        // perfil do motor (tecsys, compat-preciso, compat)
        @JsonProperty("profile")
        String profile,

        // pontos que algum candidato alcança (o resto não tem cobertura possível)
        @JsonProperty("coverable_points")
        Integer coverablePoints,

        // candidatos fora dos filtros, mas ao alcance da área (#TG-138)
        @JsonProperty("candidates_outside_filters")
        Integer candidatesOutsideFilters,

        // nenhuma solução usa menos gateways que isso
        @JsonProperty("lower_bound_gateways")
        Integer lowerBoundGateways,

        // quanto, no máximo, ainda pode faltar para o ótimo (0 = ótimo provado)
        @JsonProperty("optimality_gap_pct")
        Double optimalityGapPct,

        @JsonProperty("terrain_source")
        String terrainSource

) {
}
