package com.tecsys.domain.project;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.tecsys.domain.project.dto.ProjectHistoryResponseDto;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.infrastructure.engine.DecisionEngineClient;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.*;

/** #TG-85 — GET /api/v1/projects/{id}/history */
class ProjectHistoryTest {

    private final ObjectMapper mapper = new ObjectMapper().registerModule(new JavaTimeModule());

    private ProjectRepository projectRepository;
    private ProjectHistoryRepository historyRepository;
    private ProjectService service;

    @BeforeEach
    void setUp() {
        projectRepository = mock(ProjectRepository.class);
        historyRepository = mock(ProjectHistoryRepository.class);
        service = new ProjectService(projectRepository, mock(UserRepository.class), historyRepository,
                mock(DecisionEngineClient.class));
    }

    private ProjectHistory versao(long id, String criadoEm, String filtros) throws Exception {
        return ProjectHistory.builder()
                .id(id)
                .createdAt(Instant.parse(criadoEm))
                .filterParams(mapper.readTree(filtros))
                .polygonGeojson("{\"type\":\"Polygon\",\"coordinates\":[[[-45.9,-23.2],[-45.8,-23.2],[-45.8,-23.1],[-45.9,-23.2]]]}")
                .build();
    }

    // CT1: projeto com 2 versões → 2 itens, a mais recente primeiro
    @Test
    void projetoComDuasVersoesListaAMaisRecentePrimeiro() throws Exception {
        when(projectRepository.findByIdAndActiveTrue(7L)).thenReturn(Optional.of(new Project()));
        ProjectHistory nova = versao(2, "2026-11-09T12:00:00Z",
                "{\"bairro_names\":[\"Centro\"],\"gateway_profile\":\"tecsys\"}");
        ProjectHistory antiga = versao(1, "2026-11-08T12:00:00Z", "{\"bairro_names\":[\"Jardim Satélite\"]}");
        when(historyRepository.findAllByProject_IdOrderByCreatedAtDescIdDesc(7L)).thenReturn(List.of(nova, antiga));

        List<ProjectHistoryResponseDto> historico = service.findHistory(7L);

        assertEquals(2, historico.size());
        assertEquals(2L, historico.get(0).id());
        assertEquals(1L, historico.get(1).id());
        assertEquals("tecsys", historico.get(0).gatewayProfile());
        assertNull(historico.get(1).gatewayProfile());
        assertEquals("Centro", historico.get(0).filterParams().path("bairro_names").get(0).asText());

        // o JSON sai com data, filtros, perfil e polígono como objeto GeoJSON
        JsonNode json = mapper.readTree(mapper.writeValueAsString(historico.get(0)));
        assertEquals("09/11/2026 09:00:00", json.path("created_at").asText());
        assertEquals("Polygon", json.path("polygon").path("type").asText());
        assertTrue(json.path("filter_params").isObject());
        assertEquals("tecsys", json.path("gateway_profile").asText());
    }

    // CT2: projeto inexistente → 404 (EntityNotFoundException vira 404 no GlobalExceptionHandler)
    @Test
    void projetoInexistenteDa404() {
        when(projectRepository.findByIdAndActiveTrue(anyLong())).thenReturn(Optional.empty());

        assertThrows(EntityNotFoundException.class, () -> service.findHistory(999L));
        verifyNoInteractions(historyRepository);
    }
}
