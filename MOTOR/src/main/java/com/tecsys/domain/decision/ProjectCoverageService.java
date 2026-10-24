package com.tecsys.domain.decision;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.tecsys.domain.decision.dto.CoveredPointResponseDto;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.dto.UncoveredPointResponseDto;
import org.springframework.stereotype.Service;

@Service
public class ProjectCoverageService {

    private final ProjectCoverageRepository repository;
    private final ObjectMapper objectMapper;

    public ProjectCoverageService(ProjectCoverageRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    public void saveCoverage(long projectId, DecisionResultResponseDto response) {
        if (response == null || response.summary() == null || response.selectedGateways() == null) {
            throw new IllegalArgumentException("Payload inválido: 'summary' e 'selected_gateways' são obrigatórios.");
        }

        int summaryCoveredPoints = response.summary().coveredPoints();
        int summarySelectedGateways = response.summary().selectedGateways();

        int actualCoveredPoints = response.coveredPoints() != null ? response.coveredPoints().size() : 0;
        int actualSelectedGateways = response.selectedGateways() != null ? response.selectedGateways().size() : 0;

        // Requisito 3: Validação dos totais antes da gravação
        if (summaryCoveredPoints != actualCoveredPoints) {
            throw new IllegalArgumentException(String.format(
                    "Inconsistência na validação: summary.covered_points (%d) != len(covered_points) (%d)",
                    summaryCoveredPoints, actualCoveredPoints
            ));
        }

        if (summarySelectedGateways != actualSelectedGateways) {
            throw new IllegalArgumentException(String.format(
                    "Inconsistência na validação: summary.selected_gateways (%d) != len(selected_gateways) (%d)",
                    summarySelectedGateways, actualSelectedGateways
            ));
        }

        try {
            // Serialização dos blocos "summary" e "selected_gateways"
            String summaryJson = objectMapper.writeValueAsString(response.summary());
            String gatewaysJson = objectMapper.writeValueAsString(response.selectedGateways());

            // Montagem do bloco "points" compacto: { "covered": [[id, lon, lat], ...], "uncovered": [...] }
            ObjectNode pointsNode = objectMapper.createObjectNode();

            ArrayNode coveredArr = pointsNode.putArray("covered");
            if (response.coveredPoints() != null) {
                for (CoveredPointResponseDto p : response.coveredPoints()) {
                    ArrayNode item = coveredArr.addArray();
                    item.add(p.id());
                    item.add(p.longitude()); // Longitude primeiro
                    item.add(p.latitude());
                }
            }

            ArrayNode uncoveredArr = pointsNode.putArray("uncovered");
            // Requisito 4: Se uncoveredPoints vier vazio ou nulo, grava []
            if (response.uncoveredPoints() != null) {
                for (UncoveredPointResponseDto p : response.uncoveredPoints()) {
                    ArrayNode item = uncoveredArr.addArray();
                    item.add(p.id());
                    item.add(p.longitude()); // Longitude primeiro
                    item.add(p.latitude());
                }
            }

            String pointsJson = objectMapper.writeValueAsString(pointsNode);

            // Requisitos 1 e 2: Upsert sem concatenar SQL
            repository.upsertCoverage(projectId, summaryJson, gatewaysJson, pointsJson);

        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Erro ao serializar dados de cobertura para JSONB", e);
        }
    }
}