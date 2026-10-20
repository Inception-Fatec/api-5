package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.model.DecisionCriteria;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/internal/decision")
public class MotorDecisionController {

    private final DecisionService decisionService;

    public MotorDecisionController(DecisionService decisionService) {
        this.decisionService = decisionService;
    }

    @PostMapping("/calculate")
    public ResponseEntity<DecisionResultResponseDto> calculate(
            @RequestBody DecisionCriteria criteria
    ) {
        long start = System.nanoTime();

        DecisionResultResponseDto response =
                decisionService.calculate(criteria);

        long elapsedMs =
                (System.nanoTime() - start) / 1_000_000;

        return ResponseEntity.ok()
                .header("X-Calculation-Time-Ms", String.valueOf(elapsedMs))
                .body(response);
    }
}
