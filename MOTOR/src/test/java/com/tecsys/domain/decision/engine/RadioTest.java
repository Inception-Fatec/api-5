package com.tecsys.domain.decision.engine;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RadioTest {

    @Test
    void fsplA1kmEm915MHz() {
        assertEquals(91.67, Radio.fsplDb(1000, 915), 0.01);
    }

    @Test
    void orcamentoDoParceiroE141dB() {
        assertEquals(141.0, Radio.budgetDb(MotorParams.profile("tecsys")), 1e-9);
    }

    @Test
    void horizonteLimitaAntesDoOrcamento() {
        MotorParams p = MotorParams.profile("tecsys");
        assertTrue(Radio.budgetRangeM(p) > 250_000, "FSPL puro dá ~292 km");
        double h = Radio.radioHorizonM(6, 5, 4.0 / 3.0);
        assertTrue(h > 19_000 && h < 19_700, "horizonte 6 m / 5 m ≈ 19,3 km: " + h);
        assertEquals(h, Radio.searchRangeM(p, 6, 5), 1e-9);
    }

    @Test
    void perfisCompatUsamAlcanceFixo() {
        assertEquals(4000.0, Radio.searchRangeM(MotorParams.profile("compat"), 15, 10));
        assertEquals(4000.0, Radio.searchRangeM(MotorParams.profile("compat-preciso"), 15, 10));
    }

    @Test
    void sobrescreverParametroPelaConfiguracao() {
        MotorProperties props = new MotorProperties();
        props.setProfile("tecsys");
        props.setExtraLossDb(20.0);
        props.setMaxRangeM(5000.0);
        MotorParams p = props.toParams();
        assertEquals(121.0, Radio.budgetDb(p), 1e-9);
        assertEquals(5000.0, Radio.searchRangeM(p, 6, 5), 1e-9);
    }
}
