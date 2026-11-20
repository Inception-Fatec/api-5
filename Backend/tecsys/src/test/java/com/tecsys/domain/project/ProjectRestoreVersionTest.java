package com.tecsys.domain.project;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.gateway.GatewayProfileResolver;
import com.tecsys.domain.project.dto.ProjectHistoryResponseDto;
import com.tecsys.domain.project.dto.ProjectRecalculateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * POST /api/v1/projects/{id}/history/{historyId}/restore — voltar para uma versão:
 * ela vira a versão em uso, sem criar nem apagar versões, e o projeto recalcula.
 */
class ProjectRestoreVersionTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private ProjectRepository projectRepository;
    private ProjectHistoryRepository historyRepository;
    private DecisionEngineClient engine;
    private ProjectService service;
    private Project projeto;
    private ProjectHistory v1;
    private ProjectHistory v2;

    @BeforeEach
    void setUp() throws Exception {
        projectRepository = mock(ProjectRepository.class);
        historyRepository = mock(ProjectHistoryRepository.class);
        when(historyRepository.findVersaoAtual(any())).thenCallRealMethod();
        engine = mock(DecisionEngineClient.class);
        service = new ProjectService(projectRepository, mock(UserRepository.class), historyRepository, engine,
                mock(GatewayProfileResolver.class));

        projeto = Project.builder()
                .id(5L).name("SJC centro").distCode("391")
                .status(ProjectStatus.SUCESSO)
                .createdBy(User.builder().id(1L).name("Admin").build())
                .build();
        v1 = ProjectHistory.builder().id(1L).project(projeto)
                .filterParams(mapper.readTree("{\"mun_codes\":[\"3549904\"]}")).build();
        v2 = ProjectHistory.builder().id(2L).project(projeto)
                .filterParams(mapper.readTree("{\"mun_codes\":[\"3502507\"]}")).build();
        when(projectRepository.findByIdAndActiveTrue(5L)).thenReturn(Optional.of(projeto));
        when(projectRepository.save(any(Project.class))).thenAnswer(inv -> inv.getArgument(0));
        when(historyRepository.findById(1L)).thenReturn(Optional.of(v1));
        when(historyRepository.findById(2L)).thenReturn(Optional.of(v2));
        when(historyRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(5L)).thenReturn(Optional.of(v2));
        when(historyRepository.findAllByProject_IdOrderByCreatedAtDescIdDesc(5L)).thenReturn(List.of(v2, v1));
    }

    @Test
    void voltarParaAVersao1TornaElaAVersaoEmUsoSemCriarOutra() {
        ProjectResponseDto resposta = service.restoreVersion(5L, 1L);

        assertEquals(1L, projeto.getCurrentVersionId());
        verify(historyRepository, never()).save(any());
        assertEquals(ProjectStatus.ENVIADO, resposta.status());
        assertEquals(List.of("3549904"), resposta.munCodes());
        verify(engine).sendAfterCommit(eq(5L), any());
    }

    @Test
    void historicoMarcaAVersaoEmUso() {
        projeto.setCurrentVersionId(1L);

        List<ProjectHistoryResponseDto> versoes = service.findHistory(5L);

        assertEquals(2, versoes.size(), "nenhuma versão nova");
        assertFalse(versoes.get(0).current());
        assertTrue(versoes.get(1).current());
    }

    @Test
    void semEscolhaAVersaoEmUsoEAMaisRecente() {
        List<ProjectHistoryResponseDto> versoes = service.findHistory(5L);
        assertTrue(versoes.get(0).current());
        assertFalse(versoes.get(1).current());
    }

    // Recalcular depois de voltar: a versão nova parte da versão em uso e passa a ser ela.
    @Test
    void recalcularDepoisDeVoltarUsaAVersaoEmUsoComoBase() throws Exception {
        projeto.setCurrentVersionId(1L);
        v1.setPolygonGeojson("{\"type\":\"Polygon\",\"coordinates\":[]}");
        when(historyRepository.save(any(ProjectHistory.class))).thenAnswer(inv -> {
            ProjectHistory h = inv.getArgument(0);
            h.setId(3L);
            return h;
        });

        service.recalculate(5L, new ProjectRecalculateRequestDto(null, mapper.readTree("{}")));

        ArgumentCaptor<ProjectHistory> nova = ArgumentCaptor.forClass(ProjectHistory.class);
        verify(historyRepository).save(nova.capture());
        assertEquals(v1.getPolygonGeojson(), nova.getValue().getPolygonGeojson());
        assertEquals(3L, projeto.getCurrentVersionId());
    }

    @Test
    void versaoJaEmUsoNaoRecalcula() {
        assertThrows(BusinessRuleException.class, () -> service.restoreVersion(5L, 2L));
        verifyNoInteractions(engine);
    }

    @Test
    void versaoDeOutroProjetoDa404() {
        Project outro = Project.builder().id(8L).build();
        when(historyRepository.findById(9L)).thenReturn(Optional.of(ProjectHistory.builder()
                .id(9L).project(outro).build()));

        assertThrows(EntityNotFoundException.class, () -> service.restoreVersion(5L, 9L));
        assertNull(projeto.getCurrentVersionId());
        verifyNoInteractions(engine);
    }

    @Test
    void calculandoNaoRestaura() {
        projeto.setStatus(ProjectStatus.ENVIADO);

        assertThrows(BusinessRuleException.class, () -> service.restoreVersion(5L, 1L));
        assertNull(projeto.getCurrentVersionId());
        verifyNoInteractions(engine);
    }
}
