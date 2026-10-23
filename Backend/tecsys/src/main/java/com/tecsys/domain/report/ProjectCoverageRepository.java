package com.tecsys.domain.report;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProjectCoverageRepository extends JpaRepository<ProjectCoverage, Long> {
}