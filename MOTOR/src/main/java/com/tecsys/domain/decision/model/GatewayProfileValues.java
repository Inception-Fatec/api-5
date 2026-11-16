package com.tecsys.domain.decision.model;

import com.tecsys.domain.decision.engine.MotorParams;

/**
 * Perfil de gateway escolhido no projeto (tabela {@code gateway_profiles}, #TG-78),
 * lido do {@code filter_params.gateway_profile_id} da última versão (#TG-150).
 *
 * <p>Os valores de RF do perfil substituem os da configuração do motor; o resto
 * (modo de visada, relevo, otimização) continua vindo da configuração.
 */
public record GatewayProfileValues(
        long id,
        String name,
        double frequencyMhz,
        double txPowerDbm,
        double antennaGainDbi,
        double rxSensitivityDbm,
        double antennaHeightM,
        double sensorHeightM
) {

    /** Parâmetros do motor com os valores de RF deste perfil. */
    public MotorParams aplicar(MotorParams base) {
        return base.toBuilder()
                .frequencyMhz(frequencyMhz)
                .txPowerDbm(txPowerDbm)
                .sensitivityDbm(rxSensitivityDbm)
                // O motor soma os ganhos de Tx e Rx num só valor; o perfil cadastra o
                // ganho da antena do gateway e o sensor é considerado sem ganho.
                .antennaGainsDb(antennaGainDbi)
                .gatewayHeightM(antennaHeightM)
                .sensorHeightM(sensorHeightM)
                .gatewayProfile(id, name)
                .build();
    }
}
