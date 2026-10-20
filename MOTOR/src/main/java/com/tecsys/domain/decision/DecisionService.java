
package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.CoveredPointResponseDto;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import com.tecsys.domain.decision.dto.SelectedGatewayResponseDto;
import com.tecsys.domain.decision.dto.UncoveredPointResponseDto;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.DecisionResult;

import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

@Service
public class DecisionService {

    private static final Logger log =
            LoggerFactory.getLogger(DecisionService.class);

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

        // Inicio da medicao
        long inicio = System.nanoTime();

        // 1. Buscar os pontos de cobertura (UCs)
        var coveragePoints =
                repository.findCoveragePoints(criteria);

        long fimPontos = System.nanoTime();

        // 2. Buscar candidatos a gateway
        var candidates =
                repository.findGatewayCandidates(criteria);

        long fimCandidatos = System.nanoTime();

        // 3. Buscar relacoes espaciais pelo PostGIS
        var relations =
                repository.findCoverageRelations(
                        criteria,
                        GATEWAY_RANGE_METERS
                );

        long fimRelacoes = System.nanoTime();

        // 4. Executar o algoritmo Greedy
        DecisionResult result =
                engine.calculate(
                        coveragePoints,
                        candidates,
                        relations
                );

        long fimAlgoritmo = System.nanoTime();

        // 5. Converter o resultado para o DTO de resposta
        DecisionResultResponseDto response =
                toResponse(result);

        long fimResposta = System.nanoTime();

        // ==========================================
        // LOGS DE DESEMPENHO
        // ==========================================

        log.info("======================================");
        log.info("       PERFORMANCE DO MOTOR");
        log.info("======================================");

        log.info(
                "1. Busca de UCs: {} ms",
                (fimPontos - inicio) / 1_000_000
        );

        log.info(
                "2. Busca de candidatos: {} ms",
                (fimCandidatos - fimPontos) / 1_000_000
        );

        log.info(
                "3. Relacoes PostGIS: {} ms",
                (fimRelacoes - fimCandidatos) / 1_000_000
        );

        log.info(
                "4. Algoritmo Greedy: {} ms",
                (fimAlgoritmo - fimRelacoes) / 1_000_000
        );

        log.info(
                "5. Montagem do JSON (DTO): {} ms",
                (fimResposta - fimAlgoritmo) / 1_000_000
        );

        log.info("--------------------------------------");

        log.info(
                "TEMPO TOTAL DO SERVICO: {} ms",
                (fimResposta - inicio) / 1_000_000
        );

        log.info("--------------------------------------");

        log.info(
                "Total de UCs: {}",
                coveragePoints.size()
        );

        log.info(
                "Total de candidatos: {}",
                candidates.size()
        );

        log.info(
                "Total de relacoes espaciais: {}",
                relations.size()
        );

        log.info(
                "Gateways selecionados: {}",
                result.selectedGateways().size()
        );

        log.info(
                "Cobertura: {}%",
                result.coveragePercentage()
        );

        log.info("======================================");

        return response;
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
