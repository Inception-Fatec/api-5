package com.tecsys.domain.project;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ProjectHistoryRepository extends JpaRepository<ProjectHistory, Long> {

    /** Último registro do projeto: o mesmo que o motor usa no cálculo. */
    Optional<ProjectHistory> findFirstByProject_IdOrderByCreatedAtDescIdDesc(Long projectId);

    List<ProjectHistory> findAllByProject_IdOrderByCreatedAtDescIdDesc(Long projectId);

    @Query(value = "SELECT COUNT(*) > 0 FROM project_history WHERE filter_params->>'gateway_profile_id' = CAST(:profileId AS text)", nativeQuery = true)
    boolean existsByGatewayProfileIdInFilterParams(@Param("profileId") Long profileId);
}