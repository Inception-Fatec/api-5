package com.tecsys.domain.etl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class EtlJobRecovery {

    static final String MENSAGEM = "Interrompido por reinício do servidor";

    static final String MSG_UPLOAD_PERDIDO =
            "Upload descartado: o servidor reiniciou e o arquivo não está mais disponível. Envie de novo.";

    private final EtlJobRepository jobRepository;
    private final EtlService etlService;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void marcarJobsInterrompidos() {
        int n = jobRepository.marcarComoFalha(
                List.of(EtlJobStatus.INSPECTING, EtlJobStatus.PENDING, EtlJobStatus.RUNNING),
                EtlJobStatus.FAILED, MENSAGEM, Instant.now());
        if (n > 0) {
            log.warn("{} job(s) de ETL ficaram em andamento antes do reinício e foram marcados como FAILED", n);
        }
        // Uploads aguardando escolha (#TG-143) só continuam se a pasta ainda existe.
        for (EtlJob job : jobRepository.findByStatus(EtlJobStatus.AWAITING_SELECTION)) {
            if (job.getWorkDir() == null || !Files.isDirectory(Path.of(job.getWorkDir()))) {
                etlService.descartar(job, MSG_UPLOAD_PERDIDO);
            }
        }
    }
}