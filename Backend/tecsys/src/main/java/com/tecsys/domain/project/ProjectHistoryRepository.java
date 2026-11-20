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

    /**
     * Versão em uso do projeto: a escolhida em "voltar para esta versão"
     * ({@link Project#getCurrentVersionId()}) ou, sem escolha, a mais recente.
     * É a mesma que o motor usa no cálculo.
     */
    default Optional<ProjectHistory> findVersaoAtual(Project project) {
        Long atual = project.getCurrentVersionId();
        if (atual != null) {
            Optional<ProjectHistory> escolhida = findById(atual)
                    .filter(h -> h.getProject() != null && project.getId().equals(h.getProject().getId()));
            if (escolhida.isPresent()) return escolhida;
        }
        return findFirstByProject_IdOrderByCreatedAtDescIdDesc(project.getId());
    }

    @Query(value = "SELECT COUNT(*) > 0 FROM project_history WHERE filter_params->>'gateway_profile_id' = CAST(:profileId AS text)", nativeQuery = true)
    boolean existsByGatewayProfileIdInFilterParams(@Param("profileId") Long profileId);
}