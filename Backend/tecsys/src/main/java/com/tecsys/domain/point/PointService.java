package com.tecsys.domain.point;

import com.tecsys.domain.point.dto.PointFilterRequestDto;
import com.tecsys.domain.point.dto.PointFilterResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PointService {

    private final PointCustomRepository pointCustomRepository;

    @Transactional(readOnly = true)
    public PointFilterResponseDto filterPoints(PointFilterRequestDto request) {
        return pointCustomRepository.executeSpatialFilter(request);
    }
}