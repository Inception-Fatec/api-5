package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.CoveredPointResponseDto;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import com.tecsys.domain.decision.dto.SelectedGatewayResponseDto;
import com.tecsys.domain.decision.dto.UncoveredPointResponseDto;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.CoverageRelation;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.DecisionResult;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.service.LineOfSightService;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class DecisionService {

    private static final int GATEWAY_RANGE_METERS = 4000;
    private static final double EARTH_RADIUS_METERS = 6371000.0;

    private final DecisionRepository repository;
    private final DecisionEngine engine;
    private final LineOfSightService lineOfSightService;

    public DecisionService(
            DecisionRepository repository,
            DecisionEngine engine,
            LineOfSightService lineOfSightService
    ) {
        this.repository = repository;
        this.engine = engine;
        this.lineOfSightService = lineOfSightService;
    }

    public DecisionResultResponseDto calculate(DecisionCriteria criteria) {

        var coveragePoints = repository.findCoveragePoints(criteria);
        var candidates = repository.findGatewayCandidates(criteria);

        // Se não houver candidatos ou pontos para o critério informado, encerra
        if (coveragePoints.isEmpty() || candidates.isEmpty()) {
            return toResponse(engine.calculate(coveragePoints, candidates, List.of()));
        }

        Map<String, Double> temporaryRequestCache = new HashMap<>();

        // Processamento em memória: filtra por raio de 4km e valida a linha de visada (relevo)
        List<CoverageRelation> unobstructedRelations = new ArrayList<>();

        for (GatewayCandidate candidate : candidates) {
            for (CoveragePoint point : coveragePoints) {
                // 1. Filtro 2D por distância
                double distance = calculateDistance(
                        candidate.latitude(), candidate.longitude(),
                        point.latitude(), point.longitude()
                );

                // 2. Filtro 3D por visada/relevo se estiver dentro do raio
                if (distance <= GATEWAY_RANGE_METERS) {
                    if (lineOfSightService.hasLineOfSight(candidate, point, temporaryRequestCache)) {
                        unobstructedRelations.add(new CoverageRelation(
                                candidate.type(),
                                candidate.id(),
                                point.level(),
                                point.id()
                        ));
                    }
                }
            }
        }

        DecisionResult result = engine.calculate(
                coveragePoints,
                candidates,
                unobstructedRelations
        );

        return toResponse(result);
    }

    /**
     * Calcula a distância geodésica em metros entre duas coordenadas (Fórmula de Haversine)
     */
    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return EARTH_RADIUS_METERS * c;
    }

    private DecisionResultResponseDto toResponse(DecisionResult result) {

        DecisionSummaryResponseDto summary =
                new DecisionSummaryResponseDto(
                        result.totalPoints(),
                        result.totalCandidates(),
                        result.selectedGateways().size(),
                        result.coveredPoints(),
                        result.uncoveredPoints(),
                        result.coveragePercentage(),
                        GATEWAY_RANGE_METERS
                );

        List<SelectedGatewayResponseDto> selectedGateways =
                result.selectedGateways()
                        .stream()
                        .map(selected -> {
                            var gateway = selected.candidate();
                            return new SelectedGatewayResponseDto(
                                    selected.order(),
                                    gateway.id(),
                                    gateway.type().name(),
                                    gateway.posto(),
                                    gateway.sub(),
                                    gateway.latitude(),
                                    gateway.longitude(),
                                    selected.newPointsCovered(),
                                    selected.cumulativePointsCovered(),
                                    selected.cumulativeCoveragePercentage()
                            );
                        })
                        .toList();

        List<CoveredPointResponseDto> coveredPoints =
                result.coveredAssignments()
                        .stream()
                        .map(assignment -> {
                            var point = assignment.point();
                            return new CoveredPointResponseDto(
                                    point.id(),
                                    point.level().name(),
                                    point.latitude(),
                                    point.longitude(),
                                    point.bairro(),
                                    point.municipalityCode(),
                                    point.sub(),
                                    point.conjunto(),
                                    assignment.gateway().id(),
                                    assignment.gatewayOrder()
                            );
                        })
                        .toList();

        List<UncoveredPointResponseDto> uncoveredPoints =
                result.uncoveredCoveragePoints()
                        .stream()
                        .map(point ->
                                new UncoveredPointResponseDto(
                                        point.id(),
                                        point.level().name(),
                                        point.latitude(),
                                        point.longitude(),
                                        point.bairro(),
                                        point.municipalityCode(),
                                        point.sub(),
                                        point.conjunto()
                                )
                        )
                        .toList();

        return new DecisionResultResponseDto(
                summary,
                selectedGateways,
                coveredPoints,
                uncoveredPoints
        );
    }
}