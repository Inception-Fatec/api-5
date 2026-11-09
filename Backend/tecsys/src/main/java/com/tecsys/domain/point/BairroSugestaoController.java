package com.tecsys.domain.point;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/bairros")
@RequiredArgsConstructor
public class BairroSugestaoController {

    private final PointCustomRepository pointCustomRepository;

    @GetMapping
    public ResponseEntity<Map<String, Object>> buscar(
            @RequestParam("mun_codes") List<String> munCodes,
            @RequestParam(value = "q", required = false, defaultValue = "") String q
    ) {
        List<String> bairros = pointCustomRepository.buscarBairros(munCodes, q);
        return ResponseEntity.ok(Map.of("bairros", bairros));
    }
}