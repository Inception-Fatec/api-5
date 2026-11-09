package com.tecsys.domain.decision.engine;

import com.tecsys.domain.decision.model.CoverageAssignment;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.SelectedGateway;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Resultado de um cálculo.
 *
 * @param lowerBound limite inferior provado: nenhuma solução usa menos gateways que isso
 * @param gapPct     quanto, no máximo, ainda pode faltar para o ótimo (0 = ótimo provado)
 */
public record MotorResult(
        MotorParams params,
        double searchRadiusM,
        int totalPoints,
        int totalCandidates,
        int candidatesOutsideFilters,
        int uniquePoints,
        int uniqueCandidates,
        long visiblePairs,
        int coverablePoints,
        List<SelectedGateway> gateways,
        List<CoverageAssignment> covered,
        List<CoveragePoint> uncovered,
        // percentual de consumidores cobertos (peso dos pontos, #TG-144)
        double coveragePercentage,
        int greedyGateways,
        Integer lowerBound,
        Double gapPct,
        String optimizationMethod,
        String optimizationStatus,
        String terrainSource,
        Map<String, Double> timingsSeconds,
        long totalConsumers,
        long coverableConsumers,
        long coveredConsumers
) {

    public MotorResult {
        gateways = List.copyOf(gateways);
        covered = List.copyOf(covered);
        uncovered = List.copyOf(uncovered);
        timingsSeconds = Collections.unmodifiableMap(new LinkedHashMap<>(timingsSeconds)); // mantém a ordem das etapas
    }
}
