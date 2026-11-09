package com.tecsys.domain.project;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.project.dto.ProjectCreateRequestDto;
import com.tecsys.domain.project.dto.ProjectHistoryResponseDto;
import com.tecsys.domain.project.dto.ProjectRecalculateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ProjectService {

    private final ProjectRepository projectRepository;
    private final UserRepository userRepository;
    private final ProjectHistoryRepository projectHistoryRepository;
    private final DecisionEngineClient decisionEngineClient;

    @Transactional
    public ProjectResponseDto createProject(ProjectCreateRequestDto request, String userEmail) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new BusinessRuleException("Usuário autenticado não encontrado na base de dados."));

        Project project = Project.builder()
                .name(request.name())
                .distCode(request.distCode())
                .status(ProjectStatus.CRIADO)
                .createdBy(user)
                .build();

        return toDto(projectRepository.save(project));
    }

    @Transactional(readOnly = true)
    public List<ProjectResponseDto> findAll() {
        return projectRepository.findAllByActiveTrueOrderByLastActivityAtDescIdDesc().stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public ProjectResponseDto findById(Long id) {
        return toDto(getProjectOrThrow(id));
    }

    @Transactional
    public ProjectResponseDto updateProject(Long id, ProjectCreateRequestDto request) {
        Project project = getProjectOrThrow(id);
        project.setName(request.name());
        project.setDistCode(request.distCode());

        return toDto(projectRepository.save(project));
    }

    /** Versões do projeto, mais recente primeiro. Projeto inexistente ou excluído → 404. */
    @Transactional(readOnly = true)
    public List<ProjectHistoryResponseDto> findHistory(Long id) {
        getProjectOrThrow(id);
        return projectHistoryRepository.findAllByProject_IdOrderByCreatedAtDescIdDesc(id).stream()
                .map(h -> new ProjectHistoryResponseDto(
                        h.getId(),
                        h.getCreatedAt(),
                        h.getFilterParams(),
                        ProjectHistoryResponseDto.perfilDe(h.getFilterParams()),
                        h.getPolygonGeojson()
                ))
                .toList();
    }

    /**
     * Recalcula o projeto (#TG-84): grava uma versão nova no histórico, volta o
     * status para ENVIADO e chama o motor depois do commit. O motor lê sempre a
     * versão mais recente e substitui o resultado anterior em project_coverage.
     * Se o motor estiver fora do ar, o projeto vai para FALHA.
     */
    @Transactional
    public ProjectResponseDto recalculate(Long id, ProjectRecalculateRequestDto request) {
        Project project = getProjectOrThrow(id);

        String area = request.geometry();
        if (area == null || area.isBlank()) {
            area = projectHistoryRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(id)
                    .map(ProjectHistory::getPolygonGeojson)
                    .orElse(null);
        }

        projectHistoryRepository.save(ProjectHistory.builder()
                .project(project)
                .polygonGeojson(area)
                .filterParams(request.filterParams())
                .build());

        project.setStatus(ProjectStatus.ENVIADO);
        project.setStatusMessage(null);
        project.registrarAtividade();
        Project salvo = projectRepository.save(project);

        decisionEngineClient.sendAfterCommit(id, motivo -> marcarFalha(id, motivo));

        return new ProjectResponseDto(
                salvo.getId(),
                salvo.getName(),
                salvo.getDistCode(),
                salvo.getStatus(),
                salvo.getCreatedBy().getId(),
                salvo.getCreatedBy().getName(),
                salvo.getCreatedAt(),
                salvo.isActive(),
                ProjectResponseDto.munCodesDe(request.filterParams()),
                salvo.getStatusMessage(),
                salvo.getLastActivityAt()
        );
    }

    /**
     * Chamado fora da requisição, quando o motor não pôde ser acionado: o
     * projeto vai para FALHA com o motivo, que a tela do relatório mostra.
     */
    public void marcarFalha(Long id, String motivo) {
        projectRepository.findById(id).ifPresent(p -> {
            if (p.getStatus() == ProjectStatus.ENVIADO) {
                p.setStatus(ProjectStatus.FALHA);
                p.setStatusMessage(motivo);
                projectRepository.save(p);
            }
        });
    }

    /** Abriu o relatório (ou outra atividade): sobe o projeto nos Recentes (#TG-87). */
    @Transactional
    public void registrarAtividade(Long id) {
        Project project = getProjectOrThrow(id);
        project.registrarAtividade();
        projectRepository.save(project);
    }

    @Transactional
    public void deleteProject(Long id) {
        Project project = getProjectOrThrow(id);
        project.setActive(false);
        projectRepository.save(project);
    }

    private Project getProjectOrThrow(Long id) {
        return projectRepository.findByIdAndActiveTrue(id)
                .orElseThrow(() -> new EntityNotFoundException("Projeto não encontrado com o ID: " + id));
    }

    private ProjectResponseDto toDto(Project project) {
        return new ProjectResponseDto(
                project.getId(),
                project.getName(),
                project.getDistCode(),
                project.getStatus(),
                project.getCreatedBy().getId(),
                project.getCreatedBy().getName(),
                project.getCreatedAt(),
                project.isActive(),
                projectHistoryRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(project.getId())
                        .map(h -> ProjectResponseDto.munCodesDe(h.getFilterParams()))
                        .orElse(List.of()),
                project.getStatusMessage(),
                project.getLastActivityAt()
        );
    }
}