
package com.tecsys.domain.decision;

import com.tecsys.domain.decision.model.DecisionCriteria;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class DecisionRepositoryLayersTest {

    private DecisionCriteria criteria(
            List<String> coverage,
            List<String> candidates) {

        return new DecisionCriteria(
                List.of("391"),
                List.of("3549904"),
                List.of(),
                List.of(),
                null,
                List.of(
                        VoltageLevel.ALTO,
                        VoltageLevel.MEDIO,
                        VoltageLevel.BAIXO
                ),
                List.of(),
                List.of(),
                List.of(),
                coverage,
                candidates
        );
    }

    @Test
    void semNovosCamposMantemCamadasPadrao() {
        var jdbc = mock(NamedParameterJdbcTemplate.class);
        var repository = new DecisionRepository(jdbc);

        repository.findCoveragePoints(criteria(null, null), true);
        repository.findGatewayCandidates(
                criteria(null, null), false, 1000, true);

        var sqlCaptor = org.mockito.ArgumentCaptor.forClass(String.class);

        verify(jdbc, times(2)).query(
                sqlCaptor.capture(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );

        String pontosSql = sqlCaptor.getAllValues().get(0);
        String candidatosSql = sqlCaptor.getAllValues().get(1);

        assertTrue(pontosSql.contains("FROM ucbt u"));
        assertTrue(pontosSql.contains("FROM ucmt_pj u"));
        assertTrue(pontosSql.contains("FROM ucat_pj u"));

        assertTrue(candidatosSql.contains("FROM untrmt u"));
        assertTrue(candidatosSql.contains("FROM untrat u"));
    }

    @Test
    void somenteUntratComoCandidato() {
        var jdbc = mock(NamedParameterJdbcTemplate.class);
        var repository = new DecisionRepository(jdbc);

        repository.findGatewayCandidates(
                criteria(null, List.of("untrat")),
                false,
                1000,
                true
        );

        var sqlCaptor = org.mockito.ArgumentCaptor.forClass(String.class);

        verify(jdbc).query(
                sqlCaptor.capture(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );

        String sql = sqlCaptor.getValue();

        assertTrue(sql.contains("FROM untrat u"));
        assertFalse(sql.contains("FROM untrmt u"));
        assertFalse(sql.contains("FROM ucat_pj u"));
        assertFalse(sql.contains("FROM ucmt_pj u"));
        assertFalse(sql.contains("FROM ucbt u"));
    }

    @Test
    void aceitaPontosExternosSemAlterarPadrao() {
        DecisionCriteria padrao = criteria(null, null);

        assertFalse(padrao.isCoverageLayer("external_points"));
        assertFalse(padrao.isCandidateLayer("external_points"));

        DecisionCriteria externo = criteria(
                List.of("external_points"),
                List.of("untrat", "external_points")
        );

        assertTrue(externo.isCoverageLayer("external_points"));
        assertTrue(externo.isCandidateLayer("external_points"));
        assertTrue(externo.isCandidateLayer("untrat"));

        assertFalse(externo.isCoverageLayer("ucbt"));
        assertFalse(externo.isCandidateLayer("untrmt"));
    }

    @Test
    void consultaPontosExternosSelecionados() {
        var jdbc = mock(NamedParameterJdbcTemplate.class);
        var repository = new DecisionRepository(jdbc);

        repository.findCoveragePoints(
                criteria(List.of("external_points"), null),
                true
        );

        var sqlCaptor =
                org.mockito.ArgumentCaptor.forClass(String.class);

        verify(jdbc).query(
                sqlCaptor.capture(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );

        String sql = sqlCaptor.getValue();

        assertTrue(sql.contains("FROM external_points u"));
        assertTrue(sql.contains("u.papel = 'ponto_a_cobrir'"));
        assertTrue(sql.contains("'EXTERNO' AS level"));
        assertTrue(sql.contains("u.dist IN (:distCodes)"));
        assertTrue(sql.contains("u.mun IN (:munCodes)"));

        assertFalse(sql.contains("FROM ucbt u"));
        assertFalse(sql.contains("FROM ucmt_pj u"));
        assertFalse(sql.contains("FROM ucat_pj u"));
    }


    @Test
    void consultaSomenteCandidatosExternosQuandoSelecionados() {
        var jdbc = mock(NamedParameterJdbcTemplate.class);
        var repository = new DecisionRepository(jdbc);

        repository.findGatewayCandidates(
                criteria(null, List.of("external_points")),
                false,
                1000,
                true
        );

        var sqlCaptor =
                org.mockito.ArgumentCaptor.forClass(String.class);

        verify(jdbc).query(
                sqlCaptor.capture(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );

        String sql = sqlCaptor.getValue();

        assertTrue(sql.contains("FROM external_points u"));
        assertTrue(sql.contains("u.papel = 'candidato'"));
        assertTrue(sql.contains("'EXTERNO' AS type"));
        assertTrue(sql.contains("u.dist IN (:distCodes)"));
        assertTrue(sql.contains("u.mun IN (:munCodes)"));

        assertFalse(sql.contains("FROM untrat u"));
        assertFalse(sql.contains("FROM untrmt u"));
        assertFalse(sql.contains("FROM ucbt u"));
    }


}
