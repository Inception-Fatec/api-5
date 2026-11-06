package com.tecsys.domain.distributor;

import com.tecsys.domain.distributor.dto.DistributorResponseDto;
import com.tecsys.domain.distributor.dto.DistributorResumoProjection;
import com.tecsys.domain.distributor.dto.MunicipioResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class DistributorService {

    private final DistributorRepository distributorRepository;

    @Transactional(readOnly = true)
    public List<DistributorResponseDto> listarDistribuidoras() {
        return distributorRepository.findDistribuidorasResumo().stream()
                .map(proj -> new DistributorResponseDto(
                        proj.getDist(),
                        proj.getDistName(),
                        proj.getTotalSub()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<MunicipioResponseDto> listarMunicipiosPorDist(String dist) {
        return distributorRepository.findMunicipiosByDist(dist).stream()
                .map(proj -> new MunicipioResponseDto(
                        proj.getIbgeCode(),
                        proj.getLatitude(),
                        proj.getLongitude()
                ))
                .toList();
    }
}