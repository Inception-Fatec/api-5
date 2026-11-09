package com.tecsys.domain.project;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ProjectHistoryRepository extends JpaRepository<ProjectHistory, Long> {

    /** Último registro do projeto: o mesmo que o motor usa no cálculo. */
    Optional<ProjectHistory> findFirstByProject_IdOrderByCreatedAtDescIdDesc(Long projectId);
}