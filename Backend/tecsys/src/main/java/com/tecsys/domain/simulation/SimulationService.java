package com.tecsys.domain.simulation;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.gateway.GatewayProfileRepository;
import com.tecsys.domain.project.*;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.simulation.dto.SimulationRunRequestDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SimulationService {

    private final ProjectRepository projectRepository;
    private final ProjectHistoryRepository projectHistoryRepository;
    private final UserRepository userRepository;
    private final GatewayProfileRepository gatewayProfileRepository;
    private final DecisionEngineClient decisionEngineClient;
    private final ProjectService projectService;

    @Transactional
    public ProjectResponseDto startSimulation(SimulationRunRequestDto request, String userEmail) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new BusinessRuleException("Usuário não encontrado."));

        // Valida a existência e estado ativo do perfil de gateway submetido
        if (!gatewayProfileRepository.existsByIdAndActiveTrue(request.gatewayProfileId())) {
            throw new BusinessRuleException("Perfil de gateway selecionado não existe ou está inativo.");
        }

        // salva o Projeto
        Project project = Project.builder()
                .name(request.name())
                .distCode(request.distCode())
                .status(ProjectStatus.CRIADO)
                .createdBy(user)
                .build();
        project = projectRepository.save(project);

        // Injeta o gateway_profile_id dentro do nó JSONB do filter_params dinamicamente
        JsonNode filters = request.filterParams();
        if (filters != null && filters.isObject()) {
            ((ObjectNode) filters).put("gateway_profile_id", request.gatewayProfileId());
        }

        // salva o historico com o poligono e filtros da página de novo projeto (já com o ID do perfil)
        ProjectHistory history = ProjectHistory.builder()
                .project(project)
                .polygonGeojson(request.geometry())
                .filterParams(filters)
                .build();
        projectHistoryRepository.save(history);

        // altera status para ENVIADO
        project.setStatus(ProjectStatus.ENVIADO);
        projectRepository.save(project);

        // aciona o motor depois do commit (#TG-96); fora do ar → FALHA com motivo
        Long id = project.getId();
        decisionEngineClient.sendAfterCommit(id, motivo -> projectService.marcarFalha(id, motivo));

        return toDto(project, filters);
    }

    private ProjectResponseDto toDto(Project project, JsonNode filterParams) {
        return new ProjectResponseDto(
                project.getId(),
                project.getName(),
                project.getDistCode(),
                project.getStatus(),
                project.getCreatedBy().getId(),
                project.getCreatedBy().getName(),
                project.getCreatedAt(),
                project.getUpdatedAt(),
                project.isActive(),
                ProjectResponseDto.munCodesDe(filterParams),
                project.getStatusMessage(),
                project.getLastActivityAt()
        );
    }
}