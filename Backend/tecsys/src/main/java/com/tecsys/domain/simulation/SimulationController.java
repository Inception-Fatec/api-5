package com.tecsys.domain.simulation;

import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.simulation.dto.SimulationRunRequestDto;
import com.tecsys.domain.simulation.dto.SimulationWebhookDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;

@RestController
@RequestMapping("/api/v1/simulation")
@RequiredArgsConstructor
public class SimulationController {

    private final SimulationService simulationService;

    @PostMapping("/run")
    public ResponseEntity<ProjectResponseDto> runSimulation(
            @RequestBody @Valid SimulationRunRequestDto request,
            Principal principal) {

        ProjectResponseDto response = simulationService.startSimulation(request, principal.getName());
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
    }

    @PostMapping("/webhook/{projectId}")
    public ResponseEntity<Void> engineWebhook(
            @PathVariable Long projectId,
            @RequestBody @Valid SimulationWebhookDto webhookDto) {

        simulationService.processWebhook(projectId, webhookDto.status());
        return ResponseEntity.noContent().build();
    }
}