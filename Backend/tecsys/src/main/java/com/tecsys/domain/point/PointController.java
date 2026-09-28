package com.tecsys.domain.point;

import com.tecsys.domain.point.dto.PointFilterRequestDto;
import com.tecsys.domain.point.dto.PointFilterResponseDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/points")
@RequiredArgsConstructor
public class PointController {

    private final PointService pointService;

    @PostMapping("/filter")
    public ResponseEntity<PointFilterResponseDto> filter(@RequestBody @Valid PointFilterRequestDto request) {
        return ResponseEntity.ok(pointService.filterPoints(request));
    }
}