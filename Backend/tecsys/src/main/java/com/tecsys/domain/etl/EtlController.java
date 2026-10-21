package com.tecsys.domain.etl;

import com.tecsys.domain.etl.dto.EtlJobResponseDto;
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

    @PostMapping(value = "/upload-gdb", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<EtlJobResponseDto> uploadGdb(
            @RequestPart("file") MultipartFile file,
            @RequestParam("municipios") List<String> municipios,
            @RequestParam(value = "incluirConsumidores", defaultValue = "true") boolean incluirConsumidores,
            @AuthenticationPrincipal User currentUser) {
        EtlJobResponseDto response = etlService.startGdbUpload(file, municipios, incluirConsumidores, currentUser.getId());
        return ResponseEntity.accepted().body(response);
    }

    @GetMapping("/jobs/{id}")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<EtlJobResponseDto> getJob(@PathVariable Long id) {
        return ResponseEntity.ok(etlService.getJob(id));
    }
}