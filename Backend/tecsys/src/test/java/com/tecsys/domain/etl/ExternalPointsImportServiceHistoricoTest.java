package com.tecsys.domain.etl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.etl.dto.ExternalPointsImportResponseDto;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mock.web.MockMultipartFile;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** #TG-90 — cada importação de CSV entra no histórico de cargas (etl_jobs). */
class ExternalPointsImportServiceHistoricoTest {

    private final ObjectMapper mapper = new ObjectMapper();
    private ExternalPointJdbcRepository pontos;
    private EtlJobRepository jobs;
    private ExternalPointsImportService service;

    @BeforeEach
    void setUp() {
        pontos = mock(ExternalPointJdbcRepository.class);
        jobs = mock(EtlJobRepository.class);
        service = new ExternalPointsImportService(pontos, jobs, mapper);
    }

    private static MockMultipartFile csv(String conteudo) {
        return new MockMultipartFile("file", "pontos.csv", "text/csv", conteudo.getBytes(StandardCharsets.UTF_8));
    }

    private EtlJob jobGravado() {
        ArgumentCaptor<EtlJob> captor = ArgumentCaptor.forClass(EtlJob.class);
        verify(jobs).save(captor.capture());
        return captor.getValue();
    }

    // CT01: 10 linhas, 2 com latitude inválida → 8 importadas, 2 rejeitadas
    @Test
    void importacaoComSucessoViraJobConcluidoComOResumo() throws Exception {
        StringBuilder b = new StringBuilder("id;latitude;longitude;papel\n");
        for (int i = 1; i <= 10; i++) {
            b.append("P").append(i).append(';').append(i <= 2 ? "120" : "-23,1").append(";-45,8;candidato\n");
        }
        when(pontos.inserirNovos(eq("391"), eq("3549904"), anyList(), eq(7L)))
                .thenReturn(List.of("P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10"));
        when(jobs.save(any())).thenAnswer(inv -> { EtlJob j = inv.getArgument(0); j.setId(99L); return j; });

        ExternalPointsImportResponseDto r = service.importar(csv(b.toString()), "391", "3549904", 7L);

        assertEquals(8, r.importadas());
        EtlJob job = jobGravado();
        assertEquals(EtlJobStatus.SUCCESS, job.getStatus());
        assertEquals("pontos.csv", job.getOriginalFilename());
        assertEquals("3549904", job.getMunicipios());
        assertEquals(7L, job.getCreatedBy());
        assertNotNull(job.getStartedAt());
        assertNotNull(job.getFinishedAt());
        assertNull(job.getErrorMessage());

        JsonNode s = mapper.readTree(job.getSummaryJson());
        assertEquals("csv", s.get("tipo").asText());
        assertEquals("391", s.get("distribuidora").asText());
        assertEquals(10, s.get("total").asInt());
        assertEquals(8, s.get("importadas").asInt());
        assertEquals(2, s.get("rejeitadas").asInt());
        assertEquals(2, s.get("rejeicoes").size());
        assertEquals(2, s.get("rejeicoes").get(0).get("linha").asInt());
        assertTrue(s.get("rejeicoes").get(0).get("motivo").asText().contains("latitude fora da faixa"));
    }

    @Test
    void cabecalhoInvalidoViraJobComFalhaEOErroContinua() throws Exception {
        MockMultipartFile arquivo = csv("id,latitude,longitude,papel\nP1,1,2,candidato\n");

        BusinessRuleException e = assertThrows(BusinessRuleException.class,
                () -> service.importar(arquivo, "391", "3549904", 7L));

        EtlJob job = jobGravado();
        assertEquals(EtlJobStatus.FAILED, job.getStatus());
        assertEquals(e.getMessage(), job.getErrorMessage());
        assertEquals("csv", mapper.readTree(job.getSummaryJson()).get("tipo").asText());
        verifyNoInteractions(pontos);
    }

    @Test
    void historicoGuardaNoMaximo500Rejeicoes() throws Exception {
        StringBuilder b = new StringBuilder("id;latitude;longitude;papel\n");
        for (int i = 1; i <= 520; i++) {
            b.append("P").append(i).append(";999;-45;candidato\n");
        }

        service.importar(csv(b.toString()), "391", "3549904", 7L);

        JsonNode s = mapper.readTree(jobGravado().getSummaryJson());
        assertEquals(520, s.get("rejeitadas").asInt());
        assertEquals(ExternalPointsImportService.MAX_REJEICOES_HISTORICO, s.get("rejeicoes").size());
        assertEquals(20, s.get("rejeicoesOmitidas").asInt());
    }

    @Test
    void falhaAoGravarOHistoricoNaoDerrubaAImportacao() {
        when(jobs.save(any())).thenThrow(new RuntimeException("banco fora"));
        when(pontos.inserirNovos(any(), any(), anyList(), any())).thenReturn(List.of("P1"));

        ExternalPointsImportResponseDto r =
                service.importar(csv("id;latitude;longitude;papel\nP1;-23;-45;candidato\n"), "391", "3549904", 7L);

        assertEquals(1, r.importadas());
    }

    @Test
    void distribuidoraInvalidaNaoEntraNoHistorico() {
        assertThrows(BusinessRuleException.class,
                () -> service.importar(csv("id;latitude;longitude;papel\n"), "EDP", "3549904", 7L));
        verifyNoInteractions(jobs);
    }

    @Test
    void idsGravadosFicamNoSummaryDaImportacao() throws Exception {
        when(pontos.inserirNovos(any(), any(), anyList(), any())).thenReturn(List.of("P1", "P2"));

        service.importar(csv("id;latitude;longitude;papel\nP1;-23;-45;candidato\nP2;-23;-45;interesse\n"),
                "391", "3549904", 7L);

        JsonNode s = mapper.readTree(jobGravado().getSummaryJson());
        assertEquals(2, s.get(ExternalPointsImportService.CHAVE_IMPORTADOS).size());
        assertEquals("P2", s.get(ExternalPointsImportService.CHAVE_IMPORTADOS).get(1).asText());
    }

    private static EtlJob jobCsv(String summary) {
        return EtlJob.builder().id(99L).status(EtlJobStatus.SUCCESS).municipios("3549904").summaryJson(summary).build();
    }

    @Test
    void pontosDaImportacaoVemPelosIdsDoSummaryComLimite() {
        when(jobs.findById(99L)).thenReturn(java.util.Optional.of(jobCsv(
                "{\"tipo\":\"csv\",\"distribuidora\":\"391\",\"importadas\":3,\"importados\":[\"P1\",\"P2\",\"P3\"]}")));
        when(pontos.listarPorIds(eq("391"), anyList())).thenReturn(List.of());

        assertEquals(3, service.listarPontosDaImportacao(99L, 2).total());
        verify(pontos).listarPorIds("391", List.of("P1", "P2"));
        assertEquals(1000, service.listarPontosDaImportacao(99L, null).limite());
        assertEquals(5000, service.listarPontosDaImportacao(99L, 999_999).limite());
        assertEquals(1, service.listarPontosDaImportacao(99L, 0).limite());
    }

    @Test
    void cargaDoZipOuImportacaoAntigaNaoTemPontos() {
        when(jobs.findById(1L)).thenReturn(java.util.Optional.of(jobCsv("{\"geodatabase\":{}}")));
        when(jobs.findById(2L)).thenReturn(java.util.Optional.of(jobCsv("{\"tipo\":\"csv\",\"importadas\":4}")));
        when(jobs.findById(3L)).thenReturn(java.util.Optional.empty());

        assertEquals(0, service.listarPontosDaImportacao(1L, null).total());
        assertEquals(0, service.listarPontosDaImportacao(2L, null).total());
        assertEquals(0, service.listarPontosDaImportacao(3L, null).total());
        verifyNoInteractions(pontos);
    }

    @Test
    void listagemDoHistoricoNaoDevolveOsIds() {
        EtlJob job = jobCsv("{\"tipo\":\"csv\",\"importadas\":1,\"importados\":[\"P1\"]}");
        JsonNode summary = com.tecsys.domain.etl.dto.EtlJobResponseDto.semLog(job).summary();
        assertFalse(summary.has(ExternalPointsImportService.CHAVE_IMPORTADOS));
        assertEquals(1, summary.get("importadas").asInt());
    }
}
