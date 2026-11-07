package com.tecsys.domain.project;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProjectHistoryRepository extends JpaRepository<ProjectHistory, Long> {

    @Modifying
    @Query("DELETE FROM ProjectHistory ph WHERE ph.project.id = :projectId")
    void deleteAllByProjectId(@Param("projectId") Long projectId);
}