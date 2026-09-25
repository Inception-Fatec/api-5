package com.tecsys.domain.project;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.project.dto.ProjectCreateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
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
        return projectRepository.findAll().stream()
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
        projectRepository.delete(project);
    }

    private Project getProjectOrThrow(Long id) {
        return projectRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Projeto não encontrado com o ID: " + id));
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