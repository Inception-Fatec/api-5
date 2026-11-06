package com.tecsys.domain.report;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProjectCoverageRepository extends JpaRepository<ProjectCoverage, Long> {

    @Modifying
    @Query("DELETE FROM ProjectCoverage pc WHERE pc.project.id = :projectId")
    void deleteAllByProjectId(@Param("projectId") Long projectId);
}