package com.tecsys.domain.etl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class EtlJobRecovery {

    static final String MENSAGEM = "Interrompido por reinício do servidor";

    private final EtlJobRepository jobRepository;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void marcarJobsInterrompidos() {
        int n = jobRepository.marcarComoFalha(
                List.of(EtlJobStatus.PENDING, EtlJobStatus.RUNNING),
                EtlJobStatus.FAILED, MENSAGEM, Instant.now());
        if (n > 0) {
            log.warn("{} job(s) de ETL ficaram PENDING/RUNNING antes do reinício e foram marcados como FAILED", n);
        }
    }
}