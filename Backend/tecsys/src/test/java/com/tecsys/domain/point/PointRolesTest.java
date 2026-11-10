package com.tecsys.domain.point;

import com.tecsys.domain.point.dto.PointFilterRequestDto;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

/** #TG-92 — papéis por camada: pontos a cobrir, candidatos a gateway e rede. */
class PointRolesTest {

    private static PointFilterRequestDto pedido(List<String> tensao, List<String> cobertura, List<String> candidatas) {
        return new PointFilterRequestDto(List.of("391"), List.of("3549904"), null, null, null, null,
                tensao, null, null, null, cobertura, candidatas, null, null, null);
    }

    private static Set<String> papeis(PointFilterRequestDto p) {
        return PointCustomRepository.resolverConsultas(p).stream()
                .map(c -> c.meta().tableName() + ":" + c.cat())
                .collect(Collectors.toSet());
    }

    @Test
    void semPapeisUsaOPadraoConsumidoresETransformadores() {
        Set<String> r = papeis(pedido(List.of("all"), null, null));
        assertTrue(r.containsAll(Set.of("ucbt:ponto", "ucmt_pj:ponto", "ucat_pj:ponto",
                "untrmt:candidato", "untrat:candidato", "ssdbt:rede", "sub:rede")));
        assertFalse(r.contains("ucbt:candidato"));
    }

    // CT1: trocar papéis → a camada muda de papel (e de cor no mapa)
    @Test
    void trocarPapeisMudaACategoria() {
        Set<String> r = papeis(pedido(List.of("all"), List.of("ucbt"), List.of("ucmt_pj", "untrmt")));
        assertTrue(r.contains("ucbt:ponto"));
        assertTrue(r.contains("ucmt_pj:candidato"));
        assertFalse(r.contains("ucmt_pj:ponto"));
        assertFalse(r.contains("ucat_pj:ponto"), "consumidor sem papel não aparece");
        assertTrue(r.contains("untrat:rede"), "trafo que não é candidato vira só desenho");
    }

    @Test
    void camadaNosDoisPapeisEntraDuasVezes() {
        Set<String> r = papeis(pedido(List.of("all"), List.of("ucbt"), List.of("ucbt")));
        assertTrue(r.containsAll(Set.of("ucbt:ponto", "ucbt:candidato")));
    }

    @Test
    void candidatoIgnoraATensaoEPontoRespeita() {
        Set<String> r = papeis(pedido(List.of("baixo"), List.of("ucbt", "ucmt_pj"), List.of("untrat")));
        assertTrue(r.contains("ucbt:ponto"));
        assertFalse(r.contains("ucmt_pj:ponto"));
        assertTrue(r.contains("untrat:candidato"));
    }

    @Test
    void camadasInvalidasVoltamAoPadrao() {
        Set<String> r = papeis(pedido(List.of("all"), List.of("users"), List.of("ssdat")));
        assertTrue(r.contains("ucbt:ponto"));
        assertTrue(r.contains("untrmt:candidato"));
        assertTrue(r.contains("ssdat:rede"));
    }
}
