package com.tecsys.domain.report;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.report.dto.ProjectCoverageResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ReportService {

    private final ProjectCoverageRepository projectCoverageRepository;
    private final com.tecsys.domain.project.ProjectHistoryRepository projectHistoryRepository;

    @Transactional(readOnly = true)
    public ProjectCoverageResponseDto getCoverageByProjectId(Long projectId) {
        return projectCoverageRepository.findById(projectId)
                .map(c -> ProjectCoverageResponseDto.fromEntity(c,
                        projectHistoryRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(projectId)
                                .map(com.tecsys.domain.project.ProjectHistory::getFilterParams)
                                .orElse(null)))
                .orElseThrow(() -> new BusinessRuleException("Relatório de cobertura não encontrado para o projeto informado. O motor de cálculo pode ainda não ter finalizado."));
    }
}