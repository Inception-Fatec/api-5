package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.CalculateRequestDto;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class MotorDecisionController {

    private final DecisionService decisionService;

    public MotorDecisionController(DecisionService decisionService) {
        this.decisionService = decisionService;
    }

    @PostMapping("/calculate")
    public ResponseEntity<DecisionResultResponseDto> calculate(
            @RequestBody CalculateRequestDto request
    ) {
        long start = System.nanoTime();

        DecisionResultResponseDto response = 
                decisionService.calculateByProjectId(request.projectId());

        long elapsedMs = (System.nanoTime() - start) / 1_000_000;

        return ResponseEntity.ok()
                .header("X-Calculation-Time-Ms", String.valueOf(elapsedMs))
                .body(response);
    }
}