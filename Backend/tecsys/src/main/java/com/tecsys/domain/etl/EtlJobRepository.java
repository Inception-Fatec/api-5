package com.tecsys.domain.etl;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

public interface EtlJobRepository extends JpaRepository<EtlJob, Long> {
    List<EtlJob> findTop30ByOrderByCreatedAtDescIdDesc();

    @Modifying
    @Query("""
            update EtlJob j
               set j.status = :novoStatus,
                   j.errorMessage = :mensagem,
                   j.finishedAt = :agora
             where j.status in :statuses
            """)
    int marcarComoFalha(@Param("statuses") Collection<EtlJobStatus> statuses,
                        @Param("novoStatus") EtlJobStatus novoStatus,
                        @Param("mensagem") String mensagem,
                        @Param("agora") Instant agora);
}