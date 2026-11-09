package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.CoveredPointResponseDto;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.dto.DecisionSummaryResponseDto;
import com.tecsys.domain.decision.dto.SelectedGatewayResponseDto;
import com.tecsys.domain.decision.dto.UncoveredPointResponseDto;
import com.tecsys.domain.decision.engine.MotorEngine;
import com.tecsys.domain.decision.engine.MotorParams;
import com.tecsys.domain.decision.engine.MotorResult;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.GatewayCandidate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;

@Service
public class DecisionService {

    private static final Logger log = LoggerFactory.getLogger(DecisionService.class);

    /** O backend chama o motor antes do commit do projeto (#TG-96): espera um pouco antes de desistir. */
    private static final int LOOKUP_ATTEMPTS = 10;
    private static final long LOOKUP_WAIT_MS = 500;

    private final MotorEngine engine;
    private final ProjectLookupRepository projectLookupRepository;
    private final ProjectCoverageService projectCoverageService;
    private final ProjectStatusRepository projectStatusRepository;

    public DecisionService(
            MotorEngine engine,
            ProjectLookupRepository projectLookupRepository,
            ProjectCoverageService projectCoverageService,
            ProjectStatusRepository projectStatusRepository
    ) {
        this.engine = engine;
        this.projectLookupRepository = projectLookupRepository;
        this.projectCoverageService = projectCoverageService;
        this.projectStatusRepository = projectStatusRepository;
    }

    public DecisionResultResponseDto calculateByProjectId(long projectId) {
        try {
            DecisionCriteria criteria = findCriteria(projectId);

            // trava: sem área, cidade, conjunto ou subestação o motor varreria a distribuidora inteira
            if (!criteria.hasPolygon() && criteria.munCodes().isEmpty()
                    && criteria.subCodes().isEmpty() && criteria.conjCodes().isEmpty()) {
                throw new IllegalArgumentException("Projeto sem área, município, conjunto ou subestação.");
            }

            projectStatusRepository.updateStatus(projectId, "PROCESSANDO");
            DecisionResultResponseDto response = calculate(criteria);
            projectCoverageService.saveCoverage(projectId, response);
            projectStatusRepository.updateStatus(projectId, "SUCESSO");
            return response;

        } catch (RuntimeException | Error e) {
            // Error também (ex.: OutOfMemoryError): o projeto não pode ficar parado em ENVIADO (#TG-134)
            log.error("Erro ao processar simulação para o projeto {}: {}", projectId, e.getMessage(), e);
            String motivo = e.getMessage() == null || e.getMessage().isBlank()
                    ? e.getClass().getSimpleName()
                    : e.getMessage();
            projectStatusRepository.updateStatus(projectId, "FALHA", "O cálculo falhou: " + motivo);
            throw e;
        }
    }

    public DecisionResultResponseDto calculate(DecisionCriteria criteria) {
        MotorParams params = engine.params();
        long start = System.nanoTime();
        MotorResult result;
        try {
            result = engine.run(criteria, params);
        } catch (IOException e) {
            throw new UncheckedIOException("Falha ao obter o relevo: " + e.getMessage(), e);
        }
        logSummary(result, (System.nanoTime() - start) / 1e9);
        return toResponse(result);
    }

    private DecisionCriteria findCriteria(long projectId) {
        for (int attempt = 1; ; attempt++) {
            try {
                return projectLookupRepository.findCriteriaByProjectId(projectId);
            } catch (EmptyResultDataAccessException e) {
                if (attempt >= LOOKUP_ATTEMPTS) {
                    throw new IllegalArgumentException("Projeto " + projectId + " não encontrado ou sem histórico.", e);
                }
                try {
                    Thread.sleep(LOOKUP_WAIT_MS);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException("Interrompido aguardando o projeto " + projectId, ie);
                }
            }
        }
    }

    private void logSummary(MotorResult r, double totalSeconds) {
        log.info("======================================");
        log.info("       MOTOR DE DECISÃO — perfil {}", r.params().profile());
        log.info("======================================");
        r.timingsSeconds().forEach((k, v) -> log.info("{}: {} s", k, v));
        log.info("TEMPO TOTAL: {} s", Math.round(totalSeconds * 10) / 10.0);
        log.info("--------------------------------------");
        log.info("Pontos: {} ({} locais) | candidatos: {} ({} locais, {} fora dos filtros)",
                r.totalPoints(), r.uniquePoints(), r.totalCandidates(), r.uniqueCandidates(), r.candidatesOutsideFilters());
        log.info("Raio de busca: {} m | pares visíveis: {} | relevo: {}",
                Math.round(r.searchRadiusM()), r.visiblePairs(), r.terrainSource());
        log.info("Gateways: {} (guloso {}, limite inferior {}, gap {}%) — {} / {}",
                r.gateways().size(), r.greedyGateways(), r.lowerBound(), r.gapPct(),
                r.optimizationMethod(), r.optimizationStatus());
        log.info("Cobertura: {}% dos consumidores ({} de {}; {} cobríveis) | pontos: {} de {}",
                r.coveragePercentage(), r.coveredConsumers(), r.totalConsumers(), r.coverableConsumers(),
                r.covered().size(), r.totalPoints());
        log.info("======================================");
    }

    static DecisionResultResponseDto toResponse(MotorResult r) {
        DecisionSummaryResponseDto summary = new DecisionSummaryResponseDto(
                r.totalPoints(),
                r.totalCandidates(),
                r.gateways().size(),
                r.covered().size(),
                r.uncovered().size(),
                r.coveragePercentage(),
                (int) Math.round(r.searchRadiusM()),
                r.params().profile(),
                r.coverablePoints(),
                r.candidatesOutsideFilters(),
                r.lowerBound(),
                r.gapPct(),
                r.terrainSource(),
                r.totalConsumers(),
                r.coveredConsumers(),
                r.totalConsumers() - r.coveredConsumers(),
                r.coverableConsumers());

        List<SelectedGatewayResponseDto> gateways = r.gateways().stream().map(s -> {
            GatewayCandidate g = s.candidate();
            return new SelectedGatewayResponseDto(
                    s.order(), g.id(), g.type().name(), g.posto(), g.sub(),
                    g.latitude(), g.longitude(),
                    s.newPointsCovered(), s.cumulativePointsCovered(),
                    s.newConsumersCovered(), s.cumulativeConsumersCovered(), s.cumulativeCoveragePercentage(),
                    MotorEngine.gatewayHeight(r.params(), g), !g.insideFilters());
        }).toList();

        List<CoveredPointResponseDto> covered = r.covered().stream().map(a -> new CoveredPointResponseDto(
                a.point().id(), a.point().level().name(), a.point().latitude(), a.point().longitude(),
                a.point().bairro(), a.point().municipalityCode(), a.point().sub(), a.point().conjunto(),
                a.gateway().id(), a.gatewayOrder(), a.point().consumers())).toList();

        List<UncoveredPointResponseDto> uncovered = r.uncovered().stream().map(p -> new UncoveredPointResponseDto(
                p.id(), p.level().name(), p.latitude(), p.longitude(),
                p.bairro(), p.municipalityCode(), p.sub(), p.conjunto(), p.consumers())).toList();

        return new DecisionResultResponseDto(summary, gateways, covered, uncovered);
    }
}
