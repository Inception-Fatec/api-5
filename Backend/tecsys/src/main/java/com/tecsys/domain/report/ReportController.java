package com.tecsys.domain.report;

import com.tecsys.domain.report.dto.ProjectCoverageResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/reports")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;

    @GetMapping("/projects/{projectId}/coverage")
    public ResponseEntity<ProjectCoverageResponseDto> getProjectCoverage(@PathVariable Long projectId) {
        return ResponseEntity.ok(reportService.getCoverageByProjectId(projectId));
    }
}