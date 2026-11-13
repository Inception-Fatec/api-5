CREATE TABLE gateway_profiles (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    frequency_mhz DOUBLE PRECISION NOT NULL,
    tx_power_dbm DOUBLE PRECISION NOT NULL,
    antenna_gain_dbi DOUBLE PRECISION NOT NULL,
    rx_sensitivity_dbm DOUBLE PRECISION NOT NULL,
    antenna_height_m DOUBLE PRECISION NOT NULL,
    max_devices INTEGER NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Inserção do perfil padrão Tecsys
INSERT INTO gateway_profiles
(name, frequency_mhz, tx_power_dbm, antenna_gain_dbi, rx_sensitivity_dbm, antenna_height_m, max_devices)
VALUES
('Tecsys', 915.0, 21.0, 5.0, -120.0, 6.0, 5000);