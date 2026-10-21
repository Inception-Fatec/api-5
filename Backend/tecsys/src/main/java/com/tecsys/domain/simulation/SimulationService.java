package com.tecsys.domain.simulation;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.project.*;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.simulation.dto.SimulationRunRequestDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SimulationService {

    private final ProjectRepository projectRepository;
    private final ProjectHistoryRepository projectHistoryRepository;
    private final UserRepository userRepository;
    private final DecisionEngineClient decisionEngineClient;

    @Transactional
    public ProjectResponseDto startSimulation(SimulationRunRequestDto request, String userEmail) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new BusinessRuleException("Usuário não encontrado."));

        // salva o Projeto
        Project project = Project.builder()
                .name(request.name())
                .distCode(request.distCode())
                .status(ProjectStatus.CRIADO)
                .createdBy(user)
                .build();
        project = projectRepository.save(project);

        // salva o historico com o poligono e filtros da página de novo projeto
        ProjectHistory history = ProjectHistory.builder()
                .project(project)
                .polygonGeojson(request.polygonGeojson())
                .filterParams(request.filterParams())
                .build();
        projectHistoryRepository.save(history);

        // altera status para ENVIADO
        project.setStatus(ProjectStatus.ENVIADO);
        projectRepository.save(project);

        // aciona o motor
        decisionEngineClient.sendToEngineAsync(project.getId());

        return toDto(project);
    }

    @Transactional
    public void processWebhook(Long projectId, ProjectStatus newStatus) {
        Project project = projectRepository.findById(projectId)
                .orElseThrow(() -> new EntityNotFoundException("Projeto não encontrado."));

        project.setStatus(newStatus);
        projectRepository.save(project);
    }

    private ProjectResponseDto toDto(Project project) {
        return new ProjectResponseDto(
                project.getId(),
                project.getName(),
                project.getDistCode(),
                project.getStatus(),
                project.getCreatedBy().getId(),
                project.getCreatedAt()
        );
    }
}