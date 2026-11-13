package com.tecsys.domain.report;

import com.fasterxml.jackson.databind.JsonNode;
import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.project.Project;
import com.tecsys.domain.project.ProjectRepository;
import com.tecsys.domain.project.ProjectStatus;
import com.tecsys.domain.report.dto.ProjectComparisonItemDto;
import com.tecsys.domain.report.dto.ProjectCoverageResponseDto;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ReportService {

    private final ProjectCoverageRepository projectCoverageRepository;
    private final com.tecsys.domain.project.ProjectHistoryRepository projectHistoryRepository;
    private final ProjectRepository projectRepository;

    @Transactional(readOnly = true)
    public ProjectCoverageResponseDto getCoverageByProjectId(Long projectId) {
        return projectCoverageRepository.findById(projectId)
                .map(c -> ProjectCoverageResponseDto.fromEntity(c,
                        projectHistoryRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(projectId)
                                .map(com.tecsys.domain.project.ProjectHistory::getFilterParams)
                                .orElse(null)))
                .orElseThrow(() -> new BusinessRuleException("Relatório de cobertura não encontrado para o projeto informado. O motor de cálculo pode ainda não ter finalizado."));
    }
    private record Cenario(Project projeto, ProjectCoverage cobertura) {
    }

    @Transactional(readOnly = true)
    public List<ProjectComparisonItemDto> compareProjects(String idsBruto) {
        List<Long> ids = interpretarIds(idsBruto);

        List<Project> projetos = new ArrayList<>();
        List<Long> inexistentes = new ArrayList<>();
        for (Long id : ids) {
            Optional<Project> projeto = projectRepository.findByIdAndActiveTrue(id);
            if (projeto.isPresent()) {
                projetos.add(projeto.get());
            } else {
                inexistentes.add(id);
            }
        }
        if (!inexistentes.isEmpty()) {
            throw new EntityNotFoundException("Projeto(s) não encontrado(s) com o(s) ID(s): "
                    + inexistentes.stream().map(String::valueOf).collect(Collectors.joining(", ")));
        }

        List<Cenario> cenarios = new ArrayList<>();
        List<String> problemas = new ArrayList<>();
        for (Project projeto : projetos) {
            Optional<ProjectCoverage> cobertura = projectCoverageRepository.findById(projeto.getId());
            String motivo = motivoSemResultado(projeto, cobertura.isPresent());
            if (motivo != null) {
                problemas.add("\"" + projeto.getName() + "\" (id " + projeto.getId() + "): " + motivo);
            } else {
                cenarios.add(new Cenario(projeto, cobertura.get()));
            }
        }
        if (!problemas.isEmpty()) {
            throw new BusinessRuleException(
                    "Não é possível comparar projetos sem resultado calculado: " + String.join("; ", problemas));
        }

        return cenarios.stream()
                .map(c -> ProjectComparisonItemDto.of(c.projeto(), c.cobertura(), filterParamsDe(c.projeto())))
                .toList();
    }

    /** Parâmetros usados no cálculo: o último project_history, o mesmo que o motor lê. */
    private JsonNode filterParamsDe(Project projeto) {
        return projectHistoryRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(projeto.getId())
                .map(com.tecsys.domain.project.ProjectHistory::getFilterParams)
                .orElse(null);
    }

    /** Null quando o projeto tem resultado válido (SUCESSO e cobertura gravada); senão, o motivo. */
    private String motivoSemResultado(Project projeto, boolean temCobertura) {
        return switch (projeto.getStatus()) {
            case CRIADO -> "ainda não foi calculado";
            case ENVIADO -> "aguardando o motor de cálculo";
            case PROCESSANDO -> "cálculo em andamento";
            case FALHA -> projeto.getStatusMessage() == null || projeto.getStatusMessage().isBlank()
                    ? "o cálculo falhou"
                    : "o cálculo falhou (" + projeto.getStatusMessage() + ")";
            case SUCESSO -> temCobertura ? null : "resultado de cobertura não encontrado";
        };
    }

    private List<Long> interpretarIds(String bruto) {
        if (bruto == null || bruto.isBlank()) {
            throw new BusinessRuleException("Informe ao menos 2 projetos no parâmetro 'ids' (ex.: ids=1,2).");
        }

        Set<Long> ids = new LinkedHashSet<>();
        List<String> invalidos = new ArrayList<>();
        for (String parte : bruto.split(",")) {
            String texto = parte.trim();
            if (texto.isEmpty()) {
                continue;
            }
            try {
                ids.add(Long.parseLong(texto));
            } catch (NumberFormatException e) {
                invalidos.add(texto);
            }
        }
        if (!invalidos.isEmpty()) {
            throw new BusinessRuleException(
                    "IDs inválidos (esperado números separados por vírgula): " + String.join(", ", invalidos));
        }
        if (ids.size() < 2) {
            throw new BusinessRuleException("Informe ao menos 2 projetos distintos para comparar.");
        }
        return List.copyOf(ids);
    }
}