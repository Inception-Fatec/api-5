package com.tecsys.domain.distributor;

import com.tecsys.domain.distributor.dto.DistributorResponseDto;
import com.tecsys.domain.distributor.dto.MunicipioResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/distribuidoras")
@RequiredArgsConstructor
public class DistributorController {

    private final DistributorService distribuidoraService;

    @GetMapping
    public ResponseEntity<List<DistributorResponseDto>> listarDistribuidoras() {
        return ResponseEntity.ok(distribuidoraService.listarDistribuidoras());
    }

    @GetMapping("/{dist}/municipios")
    public ResponseEntity<List<MunicipioResponseDto>> listarMunicipios(@PathVariable String dist) {
        return ResponseEntity.ok(distribuidoraService.listarMunicipiosPorDist(dist));
    }
}