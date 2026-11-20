package com.tecsys.domain.gateway;

import com.tecsys.domain.gateway.dto.GatewayProfileRequestDto;
import com.tecsys.domain.gateway.dto.GatewayProfileResponseDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/gateway-profiles")
@RequiredArgsConstructor
public class GatewayProfileController {

    private final GatewayProfileService service;

    // Perfis são compartilhados por todos os projetos: só o ADM cria, edita e
    // exclui. O usuário comum lista e escolhe um perfil no projeto.
    @PostMapping
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<GatewayProfileResponseDto> create(@RequestBody @Valid GatewayProfileRequestDto dto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(dto));
    }

    @GetMapping
    public ResponseEntity<List<GatewayProfileResponseDto>> findAll() {
        return ResponseEntity.ok(service.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<GatewayProfileResponseDto> findById(@PathVariable Long id) {
        return ResponseEntity.ok(service.findById(id));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<GatewayProfileResponseDto> update(@PathVariable Long id, @RequestBody @Valid GatewayProfileRequestDto dto) {
        return ResponseEntity.ok(service.update(id, dto));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}