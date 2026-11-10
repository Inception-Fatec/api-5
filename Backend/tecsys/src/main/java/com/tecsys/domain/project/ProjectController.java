package com.tecsys.domain.project;

import com.tecsys.domain.project.dto.ProjectCreateRequestDto;
import com.tecsys.domain.project.dto.ProjectHistoryResponseDto;
import com.tecsys.domain.project.dto.ProjectRecalculateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/v1/projects")
@RequiredArgsConstructor
public class ProjectController {

    private final ProjectService projectService;

    @PostMapping
    public ResponseEntity<ProjectResponseDto> create(
            @RequestBody @Valid ProjectCreateRequestDto request,
            Principal principal) {
        ProjectResponseDto response = projectService.createProject(request, principal.getName());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping
    public ResponseEntity<List<ProjectResponseDto>> findAll(
            @RequestParam(required = false) String sort,
            @RequestParam(required = false) Integer limit) {
        return ResponseEntity.ok(projectService.findAll(sort, limit));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ProjectResponseDto> findById(@PathVariable Long id) {
        return ResponseEntity.ok(projectService.findById(id));
    }

    @GetMapping("/{id}/history")
    public ResponseEntity<List<ProjectHistoryResponseDto>> findHistory(@PathVariable Long id) {
        return ResponseEntity.ok(projectService.findHistory(id));
    }

    @PostMapping("/{id}/recalculate")
    public ResponseEntity<ProjectResponseDto> recalculate(
            @PathVariable Long id,
            @RequestBody @Valid ProjectRecalculateRequestDto request) {
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(projectService.recalculate(id, request));
    }

    /** Registra uma atividade (ex.: abriu o relatório) para os Recentes (#TG-87). */
    @PostMapping("/{id}/activity")
    public ResponseEntity<Void> registrarAtividade(@PathVariable Long id) {
        projectService.registrarAtividade(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}")
    public ResponseEntity<ProjectResponseDto> update(
            @PathVariable Long id,
            @RequestBody @Valid ProjectCreateRequestDto request) {
        return ResponseEntity.ok(projectService.updateProject(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        projectService.deleteProject(id);
        return ResponseEntity.noContent().build();
    }
}