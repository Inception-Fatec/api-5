package com.tecsys.domain.project;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.domain.project.dto.ProjectRecalculateRequestDto;
import com.tecsys.domain.project.dto.ProjectResponseDto;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Optional;
import java.util.function.Consumer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** #TG-84 — POST /api/v1/projects/{id}/recalculate */
class ProjectRecalculateTest {

    private static final String AREA = "{\"type\":\"Polygon\",\"coordinates\":[[[-45.9,-23.2],[-45.8,-23.2],[-45.8,-23.1],[-45.9,-23.2]]]}";

    private final ObjectMapper mapper = new ObjectMapper();

    private ProjectRepository projectRepository;
    private ProjectHistoryRepository historyRepository;
    private DecisionEngineClient engine;
    private ProjectService service;
    private Project projeto;

    @BeforeEach
    void setUp() {
        projectRepository = mock(ProjectRepository.class);
        historyRepository = mock(ProjectHistoryRepository.class);
        when(historyRepository.findVersaoAtual(any())).thenCallRealMethod();
        engine = mock(DecisionEngineClient.class);
        service = new ProjectService(projectRepository, mock(UserRepository.class), historyRepository, engine,
                mock(com.tecsys.domain.gateway.GatewayProfileResolver.class));

        projeto = Project.builder()
                .id(5L).name("SJC centro").distCode("391")
                .status(ProjectStatus.FALHA)
                .statusMessage("Motor de cálculo indisponível.")
                .createdBy(User.builder().id(1L).name("Admin").build())
                .build();
        when(projectRepository.findByIdAndActiveTrue(5L)).thenReturn(Optional.of(projeto));
        when(projectRepository.findById(5L)).thenReturn(Optional.of(projeto));
        when(projectRepository.save(any(Project.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    // CT1: recalcular com novo bairro → nova versão, status ENVIADO e motor acionado
    @Test
    void recalcularGravaNovaVersaoEVoltaParaEnviado() throws Exception {
        var filtros = mapper.readTree("{\"mun_codes\":[\"3549904\"],\"bairro_names\":[\"Centro\"]}");

        ProjectResponseDto resposta = service.recalculate(5L, new ProjectRecalculateRequestDto(AREA, filtros));

        ArgumentCaptor<ProjectHistory> versao = ArgumentCaptor.forClass(ProjectHistory.class);
        verify(historyRepository).save(versao.capture());
        assertSame(projeto, versao.getValue().getProject());
        assertEquals(AREA, versao.getValue().getPolygonGeojson());
        assertEquals("Centro", versao.getValue().getFilterParams().path("bairro_names").get(0).asText());

        assertEquals(ProjectStatus.ENVIADO, resposta.status());
        assertNull(resposta.statusMessage(), "recalcular limpa o motivo da falha anterior");
        assertEquals(java.util.List.of("3549904"), resposta.munCodes());
        verify(engine).sendAfterCommit(eq(5L), any());
    }

    // sem geometry, a versão nova mantém a área da anterior
    @Test
    void semAreaNovaReaproveitaAAreaDaVersaoAnterior() throws Exception {
        when(historyRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(5L))
                .thenReturn(Optional.of(ProjectHistory.builder().polygonGeojson(AREA).build()));

        service.recalculate(5L, new ProjectRecalculateRequestDto(null, mapper.readTree("{}")));

        ArgumentCaptor<ProjectHistory> versao = ArgumentCaptor.forClass(ProjectHistory.class);
        verify(historyRepository).save(versao.capture());
        assertEquals(AREA, versao.getValue().getPolygonGeojson());
    }

    // CT2: motor fora do ar → status FALHA, não ENVIADO
    @Test
    @SuppressWarnings("unchecked")
    void motorForaDoArDeixaOProjetoEmFalha() throws Exception {
        service.recalculate(5L, new ProjectRecalculateRequestDto(AREA, mapper.readTree("{}")));

        ArgumentCaptor<Consumer<String>> aoFalhar = ArgumentCaptor.forClass(Consumer.class);
        verify(engine).sendAfterCommit(eq(5L), aoFalhar.capture());
        aoFalhar.getValue().accept("Motor de cálculo indisponível. Verifique se ele está no ar e recalcule o projeto.");

        assertEquals(ProjectStatus.FALHA, projeto.getStatus());
        assertTrue(projeto.getStatusMessage().startsWith("Motor de cálculo indisponível"));
    }

    // CT3: projeto inexistente → 404 (EntityNotFoundException vira 404 no GlobalExceptionHandler)
    @Test
    void projetoInexistenteDa404() throws Exception {
        when(projectRepository.findByIdAndActiveTrue(999L)).thenReturn(Optional.empty());

        assertThrows(EntityNotFoundException.class,
                () -> service.recalculate(999L, new ProjectRecalculateRequestDto(AREA, mapper.readTree("{}"))));
        verifyNoInteractions(historyRepository, engine);
    }

    // #TG-150 CT5: recalcular sem mandar perfil mantém o perfil da versão anterior
    @Test
    void recalcularSemPerfilMantemOPerfilDaVersaoAnterior() throws Exception {
        var perfis = mock(com.tecsys.domain.gateway.GatewayProfileRepository.class);
        var comPerfil = new ProjectService(projectRepository, mock(UserRepository.class), historyRepository, engine,
                new com.tecsys.domain.gateway.GatewayProfileResolver(perfis));
        when(historyRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(5L))
                .thenReturn(Optional.of(ProjectHistory.builder().polygonGeojson(AREA)
                        .filterParams(mapper.readTree("{\"gateway_profile_id\":7}")).build()));

        var pedido = mapper.readTree("{\"bairro_names\":[\"Centro\"]}");
        comPerfil.recalculate(5L, new ProjectRecalculateRequestDto(null, pedido));

        ArgumentCaptor<ProjectHistory> versao = ArgumentCaptor.forClass(ProjectHistory.class);
        verify(historyRepository).save(versao.capture());
        assertEquals(7L, versao.getValue().getFilterParams().path("gateway_profile_id").asLong());
        assertEquals("Centro", versao.getValue().getFilterParams().path("bairro_names").get(0).asText());
        assertTrue(pedido.path("gateway_profile_id").isMissingNode(), "não altera o JSON recebido");
    }

    // #TG-150: perfil escolhido no recálculo troca o perfil da versão
    @Test
    void recalcularComOutroPerfilUsaOPerfilNovo() throws Exception {
        var perfis = mock(com.tecsys.domain.gateway.GatewayProfileRepository.class);
        when(perfis.existsByIdAndActiveTrue(9L)).thenReturn(true);
        var comPerfil = new ProjectService(projectRepository, mock(UserRepository.class), historyRepository, engine,
                new com.tecsys.domain.gateway.GatewayProfileResolver(perfis));
        when(historyRepository.findFirstByProject_IdOrderByCreatedAtDescIdDesc(5L))
                .thenReturn(Optional.of(ProjectHistory.builder()
                        .filterParams(mapper.readTree("{\"gateway_profile_id\":7}")).build()));

        comPerfil.recalculate(5L, new ProjectRecalculateRequestDto(AREA, mapper.readTree("{}"), 9L));

        ArgumentCaptor<ProjectHistory> versao = ArgumentCaptor.forClass(ProjectHistory.class);
        verify(historyRepository).save(versao.capture());
        assertEquals(9L, versao.getValue().getFilterParams().path("gateway_profile_id").asLong());
    }
}
