package com.tecsys.domain.etl;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;

public interface EtlJobRepository extends JpaRepository<EtlJob, Long> {
    boolean existsByStatusIn(Collection<EtlJobStatus> statuses);
}