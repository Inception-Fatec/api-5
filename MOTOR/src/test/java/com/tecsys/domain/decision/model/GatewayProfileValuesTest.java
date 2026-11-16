package com.tecsys.domain.decision.model;

import com.tecsys.domain.decision.engine.MotorParams;
import com.tecsys.domain.decision.engine.Radio;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/** #TG-150 — o perfil de gateway do projeto substitui os valores de RF da configuração. */
class GatewayProfileValuesTest {

    private static GatewayProfileValues perfil(double txDbm, double sensibilidade) {
        return new GatewayProfileValues(3L, "Teste", 915.0, txDbm, 0.0, sensibilidade, 8.0, 2.0, 0.0);
    }

    @Test
    void aplicaOsValoresDeRfEAsAlturasDoPerfil() {
        MotorParams base = MotorParams.profile("tecsys");
        MotorParams p = new GatewayProfileValues(3L, "Teste", 868.0, 14.0, 2.0, -110.0, 8.0, 2.0, 12.0).aplicar(base);

        assertEquals(868.0, p.frequencyMhz());
        assertEquals(14.0, p.txPowerDbm());
        assertEquals(-110.0, p.sensitivityDbm());
        assertEquals(2.0, p.antennaGainsDb());
        assertEquals(8.0, p.gatewayHeightM());
        assertEquals(2.0, p.sensorHeightM());
        assertEquals(12.0, p.extraLossDb());
        assertEquals(3L, p.gatewayProfileId());
        assertEquals("Teste", p.gatewayProfileName());
        // o resto continua vindo da configuração
        assertEquals(base.lineOfSight(), p.lineOfSight());
        assertEquals(base.exactSeconds(), p.exactSeconds());
        assertEquals(base.profile(), p.profile());
    }

    @Test
    void perfilPadraoTecsysNaoMudaOsParametros() {
        MotorParams base = MotorParams.profile("tecsys");
        MotorParams p = new GatewayProfileValues(1L, "Tecsys", 915.0, 21.0, 0.0, -120.0, 6.0, 5.0, 0.0).aplicar(base);
        assertEquals(base.frequencyMhz(), p.frequencyMhz());
        assertEquals(base.txPowerDbm(), p.txPowerDbm());
        assertEquals(base.sensitivityDbm(), p.sensitivityDbm());
        assertEquals(base.antennaGainsDb(), p.antennaGainsDb());
        assertEquals(base.gatewayHeightM(), p.gatewayHeightM());
        assertEquals(base.sensorHeightM(), p.sensorHeightM());
        assertEquals(base.extraLossDb(), p.extraLossDb());
    }

    @Test
    void semPerfilAConfiguracaoNaoTemPerfilDeGateway() {
        MotorParams base = MotorParams.profile("tecsys");
        assertNull(base.gatewayProfileId());
        assertNull(base.gatewayProfileName());
    }

    // CT2/CT3 da US 17: menos potência ou pior sensibilidade → menor alcance (logo, mais gateways)
    @Test
    void menosPotenciaOuPiorSensibilidadeReduzemOAlcance() {
        MotorParams base = MotorParams.profile("tecsys");
        double alcance21 = Radio.budgetRangeM(perfil(21.0, -120.0).aplicar(base));
        double alcance14 = Radio.budgetRangeM(perfil(14.0, -120.0).aplicar(base));
        double alcance110 = Radio.budgetRangeM(perfil(21.0, -110.0).aplicar(base));
        double alcance130 = Radio.budgetRangeM(perfil(21.0, -130.0).aplicar(base));
        assertTrue(alcance14 < alcance21, "14 dBm alcança menos que 21 dBm");
        assertTrue(alcance110 < alcance130, "-110 dBm alcança menos que -130 dBm");
    }

    // com perda adicional, a potência passa a mudar o alcance (14 dBm alcança menos que 21 dBm)
    @Test
    void perdaAdicionalFazAPotenciaInfluirNoAlcance() {
        MotorParams base = MotorParams.profile("tecsys");
        GatewayProfileValues p21 = new GatewayProfileValues(1L, "21", 915.0, 21.0, 0.0, -120.0, 6.0, 5.0, 20.0);
        GatewayProfileValues p14 = new GatewayProfileValues(2L, "14", 915.0, 14.0, 0.0, -120.0, 6.0, 5.0, 20.0);
        double a21 = Radio.budgetRangeM(p21.aplicar(base));
        double a14 = Radio.budgetRangeM(p14.aplicar(base));
        assertTrue(a14 < a21);
        assertTrue(a21 < 35_000 && a21 > 25_000, "20 dB de perda: ~29 km com 21 dBm, foi " + a21);
        assertTrue(a14 < 15_000 && a14 > 10_000, "20 dB de perda: ~13 km com 14 dBm, foi " + a14);
    }
}
