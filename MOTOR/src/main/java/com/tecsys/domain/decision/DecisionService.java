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
import com.tecsys.domain.decision.service.AreaElevationRaster;
import com.tecsys.domain.decision.service.LineOfSightService;
import com.tecsys.domain.decision.service.ElevationService;

import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;

@Service
public class DecisionService {

    private static final Logger log =
            LoggerFactory.getLogger(DecisionService.class);

    private static final int GATEWAY_RANGE_METERS = 4000;
    private static final double EARTH_RADIUS_METERS = 6371000.0;

    private final DecisionRepository repository;
    private final DecisionEngine engine;
    private final LineOfSightService lineOfSightService;
    private final ElevationService elevationService;
    private final ProjectLookupRepository projectLookupRepository;
    private final ProjectCoverageService projectCoverageService;
    private final ProjectStatusRepository projectStatusRepository;

    public DecisionService(
            DecisionRepository repository,
            DecisionEngine engine,
            LineOfSightService lineOfSightService,
            ElevationService elevationService,
            ProjectLookupRepository projectLookupRepository,
            ProjectCoverageService projectCoverageService,
            ProjectStatusRepository projectStatusRepository
    ) {
        this.repository = repository;
        this.engine = engine;
        this.lineOfSightService = lineOfSightService;
        this.elevationService = elevationService;
        this.projectLookupRepository = projectLookupRepository;
        this.projectCoverageService = projectCoverageService;
        this.projectStatusRepository = projectStatusRepository;
    }
    
    public DecisionResultResponseDto calculateByProjectId(long projectId) {
        try {
            DecisionCriteria criteria = projectLookupRepository.findCriteriaByProjectId(projectId);

            // trava: sem área, cidade, conjunto ou subestação o motor varreria a distribuidora inteira
            if (!criteria.hasPolygon() && criteria.munCodes().isEmpty()
                    && criteria.subCodes().isEmpty() && criteria.conjCodes().isEmpty()) {
                throw new IllegalArgumentException("Projeto sem área, município, conjunto ou subestação.");
            }

            DecisionResultResponseDto response = calculate(criteria);
            projectCoverageService.saveCoverage(projectId, response);
            projectStatusRepository.updateStatus(projectId, "SUCESSO");
            return response;

        } catch (Exception e) {
            log.error("Erro ao processar simulação para o projeto {}: {}", projectId, e.getMessage(), e);
            projectStatusRepository.updateStatus(projectId, "FALHA");
            throw e;
        }
    }

    public DecisionResultResponseDto calculate(
            Long projectId,
            DecisionCriteria criteria
    ) {
        DecisionResultResponseDto response = calculate(criteria);

        if (projectId != null) {
            projectCoverageService.saveCoverage(projectId, response);
        }

        return response;
    }

    public DecisionResultResponseDto calculate(
            DecisionCriteria criteria
    ) {

        long inicio = System.nanoTime();

        // 1. Buscar os pontos de cobertura (UCs)
        var coveragePoints =
                repository.findCoveragePoints(criteria);

        long fimPontos = System.nanoTime();

        // 2. Buscar candidatos a gateway
        var candidates =
                repository.findGatewayCandidates(criteria);

        long fimCandidatos = System.nanoTime();

        if (coveragePoints.isEmpty() || candidates.isEmpty()) {
            DecisionResult emptyResult = engine.calculate(coveragePoints, candidates, List.of());
            return toResponse(emptyResult);
        }

        // Calcula a Bounding Box de toda a área de interesse
        double minLat = Double.MAX_VALUE;
        double maxLat = -Double.MAX_VALUE;
        double minLon = Double.MAX_VALUE;
        double maxLon = -Double.MAX_VALUE;

        for (GatewayCandidate c : candidates) {
            minLat = Math.min(minLat, c.latitude());
            maxLat = Math.max(maxLat, c.latitude());
            minLon = Math.min(minLon, c.longitude());
            maxLon = Math.max(maxLon, c.longitude());
        }
        for (CoveragePoint p : coveragePoints) {
            minLat = Math.min(minLat, p.latitude());
            maxLat = Math.max(maxLat, p.latitude());
            minLon = Math.min(minLon, p.longitude());
            maxLon = Math.max(maxLon, p.longitude());
        }

        // Margem de segurança de ~4.4km (~0.04 graus) para o alcance do sinal dos gateways
        double margin = 0.04;
        double south = minLat - margin;
        double north = maxLat + margin;
        double west = minLon - margin;
        double east = maxLon + margin;

        List<CoverageRelation> unobstructedRelations = new ArrayList<>();

        // 3. Download temporário da Bounding Box via OpenTopography com try-with-resources
        long inicioDownload = System.nanoTime();
        try (AreaElevationRaster raster = elevationService.downloadAreaRaster(south, north, west, east)) {
            long fimDownload = System.nanoTime();
            log.info("Download e carregamento da área de relevo (BBox) concluído em {} ms",
                    (fimDownload - inicioDownload) / 1_000_000);

            for (GatewayCandidate candidate : candidates) {
                for (CoveragePoint point : coveragePoints) {
                    double distance = calculateDistance(
                            candidate.latitude(), candidate.longitude(),
                            point.latitude(), point.longitude()
                    );

                    if (distance <= GATEWAY_RANGE_METERS) {
                        if (lineOfSightService.hasLineOfSight(candidate, point, raster)) {
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
        }

        long fimRelacoes = System.nanoTime();

        // 4. Executar o algoritmo Greedy
        DecisionResult result =
                engine.calculate(
                        coveragePoints,
                        candidates,
                        unobstructedRelations
                );

        long fimAlgoritmo = System.nanoTime();

        // 5. Converter o resultado para o DTO de resposta
        DecisionResultResponseDto response =
                toResponse(result);

        long fimResposta = System.nanoTime();

        // LOGS DE DESEMPENHO
        log.info("======================================");
        log.info("       PERFORMANCE DO MOTOR");
        log.info("======================================");
        log.info("1. Busca de UCs: {} ms", (fimPontos - inicio) / 1_000_000);
        log.info("2. Busca de candidatos: {} ms", (fimCandidatos - fimPontos) / 1_000_000);
        log.info("3. Relacoes e Visada 3D (Relevo): {} ms", (fimRelacoes - fimCandidatos) / 1_000_000);
        log.info("4. Algoritmo Greedy: {} ms", (fimAlgoritmo - fimRelacoes) / 1_000_000);
        log.info("5. Montagem do JSON (DTO): {} ms", (fimResposta - fimAlgoritmo) / 1_000_000);
        log.info("--------------------------------------");
        log.info("TEMPO TOTAL DO SERVICO: {} ms", (fimResposta - inicio) / 1_000_000);
        log.info("--------------------------------------");
        log.info("Total de UCs: {}", coveragePoints.size());
        log.info("Total de candidatos: {}", candidates.size());
        log.info("Total de relacoes espaciais desobstruidas: {}", unobstructedRelations.size());
        log.info("Gateways selecionados: {}", result.selectedGateways().size());
        log.info("Cobertura: {}%", result.coveragePercentage());
        log.info("======================================");

        return response;
    }

    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return EARTH_RADIUS_METERS * c;
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