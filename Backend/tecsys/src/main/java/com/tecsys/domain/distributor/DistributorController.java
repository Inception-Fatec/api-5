package com.tecsys.domain.distributor;

import com.tecsys.domain.distributor.dto.DistributorCreateRequestDto;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;

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

    /** Com {@code incluirCadastradas=true}, inclui as cadastradas ainda sem dados (modal de CSV). */
    @GetMapping
    public ResponseEntity<List<DistributorResponseDto>> listarDistribuidoras(
            @RequestParam(value = "incluirCadastradas", defaultValue = "false") boolean incluirCadastradas) {
        return ResponseEntity.ok(distribuidoraService.listarDistribuidoras(incluirCadastradas));
    }

    /** Cadastra distribuidora personalizada, sem BDGD (#TG-151). Só ADM. */
    @PostMapping
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<DistributorResponseDto> cadastrar(@RequestBody @Valid DistributorCreateRequestDto request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(distribuidoraService.cadastrar(request));
    }

    @GetMapping("/{dist}/municipios")
    public ResponseEntity<List<MunicipioResponseDto>> listarMunicipios(@PathVariable String dist) {
        return ResponseEntity.ok(distribuidoraService.listarMunicipiosPorDist(dist));
    }
}