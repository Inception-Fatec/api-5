package com.tecsys.domain.project;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.project.dto.ProjectCreateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
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
        if ("recent".equalsIgnoreCase(sort)) {
            Sort sortByUpdated = Sort.by(Sort.Direction.DESC, "updatedAt");

            if (limit != null && limit > 0) {
                return projectRepository.findAllByActiveTrue(PageRequest.of(0, limit, sortByUpdated))
                        .stream()
                        .map(this::toDto)
                        .toList();
            }
            return projectRepository.findAllByActiveTrue(sortByUpdated)
                    .stream()
                    .map(this::toDto)
                    .toList();
        }

        return projectRepository.findAllByActiveTrue().stream()
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
                projectHistoryRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(project.getId())
                        .map(h -> ProjectResponseDto.munCodesDe(h.getFilterParams()))
                        .orElse(List.of())
        );
    }
}