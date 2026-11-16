package com.tecsys.domain.gateway;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "gateway_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GatewayProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String name;

    @Column(name = "frequency_mhz", nullable = false)
    private Double frequencyMhz;

    @Column(name = "tx_power_dbm", nullable = false)
    private Double txPowerDbm;

    @Column(name = "antenna_gain_dbi", nullable = false)
    private Double antennaGainDbi;

    @Column(name = "rx_sensitivity_dbm", nullable = false)
    private Double rxSensitivityDbm;

    @Column(name = "antenna_height_m", nullable = false)
    private Double antennaHeightM;

    /** Altura do dispositivo (sensor) usada na visada (#TG-150). */
    @Column(name = "sensor_height_m", nullable = false)
    private Double sensorHeightM;

    @Column(name = "max_devices", nullable = false)
    private Integer maxDevices;

    @Builder.Default
    @Column(nullable = false, columnDefinition = "boolean default true")
    private boolean active = true;

    /** Perfil usado quando o projeto não informa um (#TG-150). Só um é padrão. */
    @Builder.Default
    @Column(name = "is_default", nullable = false)
    private boolean padrao = false;
}