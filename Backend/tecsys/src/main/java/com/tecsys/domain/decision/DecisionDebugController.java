package com.tecsys.domain.decision;

import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/decision")
public class DecisionDebugController {

    private final DecisionService decisionService;

    public DecisionDebugController(
            DecisionService decisionService
    ) {
        this.decisionService = decisionService;
    }

    @PostMapping("/debug")
    public ResponseEntity<DecisionResultResponseDto> debug() {

        DecisionCriteria criteria =
                new DecisionCriteria(
                        List.of(),
                        List.of("3549904"),
                        List.of("17113"),
                        List.of("AVP"),
                        null,
                        List.of(VoltageLevel.BAIXO),
                        List.of(),
                        List.of(),
                        List.of()
                );

        long start = System.nanoTime();

        DecisionResultResponseDto response =
                decisionService.calculate(criteria);

        long elapsedMs =
                (System.nanoTime() - start)
                        / 1_000_000;

        return ResponseEntity
                .ok()
                .header(
                        "X-Calculation-Time-Ms",
                        String.valueOf(elapsedMs)
                )
                .body(response);
    }
}