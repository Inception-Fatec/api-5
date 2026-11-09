package com.tecsys.domain.project;

import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** #TG-87 — atividade mais recente do projeto (seção "Recentes"). */
class ProjectActivityTest {

    private ProjectRepository projectRepository;
    private ProjectService service;

    @BeforeEach
    void setUp() {
        projectRepository = mock(ProjectRepository.class);
        service = new ProjectService(projectRepository, mock(UserRepository.class),
                mock(ProjectHistoryRepository.class), mock(DecisionEngineClient.class));
        when(projectRepository.save(any(Project.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private static Project projeto(long id, Instant atividade) {
        return Project.builder().id(id).name("P" + id).distCode("391")
                .status(ProjectStatus.SUCESSO)
                .createdBy(User.builder().id(1L).name("Admin").build())
                .lastActivityAt(atividade)
                .build();
    }

    // CT1: abrir o relatório de um projeto antigo → atividade agora
    @Test
    void abrirRelatorioAtualizaAAtividade() {
        Instant antiga = Instant.parse("2026-01-01T00:00:00Z");
        Project p = projeto(3, antiga);
        when(projectRepository.findByIdAndActiveTrue(3L)).thenReturn(Optional.of(p));

        service.registrarAtividade(3L);

        assertTrue(p.getLastActivityAt().isAfter(antiga));
        verify(projectRepository).save(p);
    }

    @Test
    void listaVemNaOrdemDeAtividadeComOCampo() {
        Instant agora = Instant.parse("2026-11-09T12:00:00Z");
        when(projectRepository.findAllByActiveTrueOrderByLastActivityAtDescIdDesc())
                .thenReturn(List.of(projeto(1, agora), projeto(7, agora.minusSeconds(60))));

        var lista = service.findAll();

        assertEquals(List.of(1L, 7L), lista.stream().map(d -> d.id()).toList());
        assertEquals(agora, lista.get(0).lastActivityAt());
    }

    @Test
    void projetoInexistenteDa404() {
        when(projectRepository.findByIdAndActiveTrue(9L)).thenReturn(Optional.empty());
        assertThrows(EntityNotFoundException.class, () -> service.registrarAtividade(9L));
    }
}
