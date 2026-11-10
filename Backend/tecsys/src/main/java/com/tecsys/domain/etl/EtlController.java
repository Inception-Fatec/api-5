package com.tecsys.domain.etl;

import com.tecsys.domain.etl.dto.EtlJobResponseDto;
import com.tecsys.domain.etl.dto.ExternalPointsImportResponseDto;
import com.tecsys.domain.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/v1/etl")
@RequiredArgsConstructor
public class EtlController {

    private final EtlService etlService;
    private final ExternalPointsImportService externalPointsImportService;

    @PostMapping(value = "/upload-gdb", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<EtlJobResponseDto> uploadGdb(
            @RequestPart("file") MultipartFile file,
            @RequestParam(value = "municipios", required = false) List<String> municipios,
            @RequestParam(value = "incluirConsumidores", defaultValue = "true") boolean incluirConsumidores,
            @AuthenticationPrincipal User currentUser) {
        EtlJobResponseDto response = etlService.startGdbUpload(file, municipios, incluirConsumidores, currentUser.getId());
        return ResponseEntity.accepted().body(response);
    }

    /** Importação de pontos externos por CSV (#89, RF-07): candidato, ponto_a_cobrir ou interesse. */
    @PostMapping(value = "/upload-csv", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<ExternalPointsImportResponseDto> uploadCsv(
            @RequestPart("file") MultipartFile file,
            @RequestParam("distribuidora") String distribuidora,
            @RequestParam("municipio") String municipio,
            @AuthenticationPrincipal User currentUser) {
        return ResponseEntity.ok(
                externalPointsImportService.importar(file, distribuidora, municipio, currentUser.getId()));
    }

    @GetMapping("/jobs")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<List<EtlJobResponseDto>> listJobs() {
        return ResponseEntity.ok(etlService.listarJobs());
    }

    /** Etapa 2 do upload pela tela (#TG-143): escolhe os municípios e inicia a carga. */
    @PostMapping("/jobs/{id}/iniciar")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<EtlJobResponseDto> iniciar(@PathVariable Long id, @RequestBody IniciarCargaRequest body) {
        boolean consumidores = body.incluirConsumidores() == null || body.incluirConsumidores();
        return ResponseEntity.accepted().body(etlService.iniciarCarga(id, body.municipios(), consumidores));
    }

    @PostMapping("/jobs/{id}/cancelar")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<EtlJobResponseDto> cancelar(@PathVariable Long id) {
        return ResponseEntity.ok(etlService.cancelar(id));
    }

    public record IniciarCargaRequest(List<String> municipios, Boolean incluirConsumidores) {}

    @GetMapping("/jobs/{id}")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<EtlJobResponseDto> getJob(@PathVariable Long id) {
        return ResponseEntity.ok(etlService.getJob(id));
    }
}