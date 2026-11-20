package com.tecsys.domain.gateway;

import org.junit.jupiter.api.Test;
import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.*;

/** Perfis valem para todos os projetos: só o ADM cria, edita e exclui; todos listam. */
class GatewayProfilePermissaoTest {

    private static PreAuthorize regra(String metodo) {
        for (Method m : GatewayProfileController.class.getDeclaredMethods()) {
            if (m.getName().equals(metodo)) return m.getAnnotation(PreAuthorize.class);
        }
        throw new AssertionError("método não encontrado: " + metodo);
    }

    @Test
    void criarEditarExcluirSoAdm() {
        for (String metodo : new String[]{"create", "update", "delete"}) {
            PreAuthorize regra = regra(metodo);
            assertNotNull(regra, metodo + " precisa de @PreAuthorize");
            assertEquals("hasRole('ADM')", regra.value());
        }
    }

    @Test
    void listarEConsultarLiberadosParaTodos() {
        assertNull(regra("findAll"));
        assertNull(regra("findById"));
    }
}
