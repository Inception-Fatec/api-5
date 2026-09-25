package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.CoveredPointResponseDto;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import com.tecsys.domain.decision.dto.SelectedGatewayResponseDto;
import com.tecsys.domain.decision.dto.UncoveredPointResponseDto;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.DecisionResult;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class DecisionService {

    
    private static final int GATEWAY_RANGE_METERS = 4000;

    private final DecisionRepository repository;
    private final DecisionEngine engine;

    public DecisionService(
            DecisionRepository repository,
            DecisionEngine engine
    ) {
        this.repository = repository;
        this.engine = engine;
    }

    public DecisionResultResponseDto calculate(
            DecisionCriteria criteria
    ) {

        
        var coveragePoints =
                repository.findCoveragePoints(criteria);

        
        var candidates =
                repository.findGatewayCandidates(criteria);

        
        var relations =
                repository.findCoverageRelations(
                        criteria,
                        GATEWAY_RANGE_METERS
                );

        
        DecisionResult result =
                engine.calculate(
                        coveragePoints,
                        candidates,
                        relations
                );

        
        return toResponse(result);
    }

    private DecisionResultResponseDto toResponse(
            DecisionResult result
    ) {

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

                            var gateway =
                                    selected.candidate();

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

                            var point =
                                    assignment.point();

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