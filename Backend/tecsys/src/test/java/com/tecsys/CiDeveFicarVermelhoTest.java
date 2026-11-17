package com.tecsys;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Temporário (#TG-152): prova que o CI fica vermelho com teste quebrado. Será revertido. */
class CiDeveFicarVermelhoTest {

    @Test
    void falhaDePropositoParaTestarOCi() {
        assertEquals(1, 2, "Falha proposital para testar o CI");
    }
}
