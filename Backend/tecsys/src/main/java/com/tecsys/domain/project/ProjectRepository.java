package com.tecsys.domain.project;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProjectRepository extends JpaRepository<Project, Long> {

    // Soft delete: projetos com active = false não aparecem para o usuário.
    List<Project> findAllByActiveTrue();

    /** Ativos, da atividade mais recente para a mais antiga (#TG-87). */
    List<Project> findAllByActiveTrueOrderByLastActivityAtDescIdDesc();

    Optional<Project> findByIdAndActiveTrue(Long id);
}