package com.tecsys.domain.project;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.project.dto.ProjectCreateRequestDto;
import com.tecsys.domain.project.dto.ProjectHistoryResponseDto;
import com.tecsys.domain.project.dto.ProjectRecalculateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.domain.gateway.GatewayProfileResolver;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
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
    private final GatewayProfileResolver gatewayProfileResolver;

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
    public List<ProjectResponseDto> findAll(String sort, Integer limit) {
        // Atividade mais recente (criar, recalcular ou abrir o relatório) primeiro (#TG-87).
        // sort=recent continua aceito (#TG-87, PR #81); limit corta a lista.
        if (limit != null && limit > 0) {
            Sort porAtividade = Sort.by(Sort.Direction.DESC, "lastActivityAt").and(Sort.by(Sort.Direction.DESC, "id"));
            return projectRepository.findAllByActiveTrue(PageRequest.of(0, limit, porAtividade)).stream()
                    .map(this::toDto)
                    .toList();
        }
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

    /**
     * Versões do projeto, mais recente primeiro, com a versão em uso marcada
     * ({@code current}). Projeto inexistente ou excluído → 404.
     */
    @Transactional(readOnly = true)
    public List<ProjectHistoryResponseDto> findHistory(Long id) {
        Project project = getProjectOrThrow(id);
        Long atual = projectHistoryRepository.findVersaoAtual(project).map(ProjectHistory::getId).orElse(null);
        return projectHistoryRepository.findAllByProject_IdOrderByCreatedAtDescIdDesc(id).stream()
                .map(h -> new ProjectHistoryResponseDto(
                        h.getId(),
                        h.getCreatedAt(),
                        h.getFilterParams(),
                        ProjectHistoryResponseDto.perfilDe(h.getFilterParams()),
                        h.getPolygonGeojson(),
                        h.getId().equals(atual)
                ))
                .toList();
    }

    /**
     * Recalcula o projeto (#TG-84): grava uma versão nova no histórico, volta o
     * status para ENVIADO e chama o motor depois do commit. A versão nova passa a
     * ser a versão em uso, que o motor lê; o resultado anterior em
     * project_coverage é substituído. Se o motor estiver fora do ar, o projeto
     * vai para FALHA.
     */
    @Transactional
    public ProjectResponseDto recalculate(Long id, ProjectRecalculateRequestDto request) {
        Project project = getProjectOrThrow(id);

        // Base dos valores que não vierem no pedido: a versão em uso.
        ProjectHistory anterior = projectHistoryRepository.findVersaoAtual(project).orElse(null);

        String area = request.geometry();
        if ((area == null || area.isBlank()) && anterior != null) {
            area = anterior.getPolygonGeojson();
        }

        // Perfil: o do pedido (campo ou dentro dos filtros), senão o da versão anterior,
        // senão o padrão (#TG-150). O motor lê o perfil do filter_params.
        ObjectNode filtros = request.filterParams() != null && request.filterParams().isObject()
                ? ((ObjectNode) request.filterParams()).deepCopy()
                : JsonNodeFactory.instance.objectNode();
        Long pedido = request.gatewayProfileId() != null
                ? request.gatewayProfileId()
                : GatewayProfileResolver.idEm(filtros);
        Long perfilId = gatewayProfileResolver.resolver(pedido, anterior != null ? anterior.getFilterParams() : null);
        if (perfilId != null) {
            filtros.put(GatewayProfileResolver.CAMPO, perfilId);
        }

        ProjectHistory nova = projectHistoryRepository.save(ProjectHistory.builder()
                .project(project)
                .polygonGeojson(area)
                .filterParams(filtros)
                .build());
        project.setCurrentVersionId(nova != null ? nova.getId() : null);
        return calcular(project, filtros);
    }

    /**
     * Volta o projeto para uma versão do histórico: ela passa a ser a versão em
     * uso (nenhuma versão é criada nem apagada) e o projeto é recalculado com a
     * área e os filtros dela.
     */
    @Transactional
    public ProjectResponseDto restoreVersion(Long id, Long historyId) {
        Project project = getProjectOrThrow(id);
        if (project.getStatus() == ProjectStatus.ENVIADO || project.getStatus() == ProjectStatus.PROCESSANDO) {
            throw new BusinessRuleException("Aguarde o cálculo atual terminar para voltar a uma versão.");
        }
        ProjectHistory versao = projectHistoryRepository.findById(historyId)
                .filter(h -> h.getProject() != null && id.equals(h.getProject().getId()))
                .orElseThrow(() -> new EntityNotFoundException("Versão não encontrada neste projeto."));
        boolean jaEmUso = projectHistoryRepository.findVersaoAtual(project)
                .map(h -> historyId.equals(h.getId()))
                .orElse(false);
        if (jaEmUso && project.getStatus() == ProjectStatus.SUCESSO) {
            throw new BusinessRuleException("Essa já é a versão em uso.");
        }

        project.setCurrentVersionId(versao.getId());
        return calcular(project, versao.getFilterParams());
    }

    /** Volta o status para ENVIADO e chama o motor depois do commit. */
    private ProjectResponseDto calcular(Project project, com.fasterxml.jackson.databind.JsonNode filtros) {
        Long id = project.getId();
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
                salvo.getUpdatedAt(),
                salvo.isActive(),
                ProjectResponseDto.munCodesDe(filtros),
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
                project.getUpdatedAt(),
                project.isActive(),
                projectHistoryRepository.findVersaoAtual(project)
                        .map(h -> ProjectResponseDto.munCodesDe(h.getFilterParams()))
                        .orElse(List.of()),
                project.getStatusMessage(),
                project.getLastActivityAt()
        );
    }
}