-- #TG-150: o motor passa a usar o perfil de gateway do projeto no cálculo.
--  * sensor_height_m: altura do dispositivo (sensor), que o motor usa na visada
--    junto com a altura da antena do gateway. Padrão Tecsys: 5 m.
--  * is_default: perfil usado quando o projeto não informa um (front antigo,
--    projetos antigos e recálculo sem perfil). Só pode haver um.
--  * O perfil padrão volta a ter ganho de antena 0 dBi: é o valor que o motor
--    usava até aqui, e a Tecsys não informou ganho. Assim o resultado dos
--    projetos não muda sem uma decisão explícita.
ALTER TABLE gateway_profiles ADD COLUMN IF NOT EXISTS sensor_height_m DOUBLE PRECISION NOT NULL DEFAULT 5.0;
ALTER TABLE gateway_profiles ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;

INSERT INTO gateway_profiles
    (name, frequency_mhz, tx_power_dbm, antenna_gain_dbi, rx_sensitivity_dbm, antenna_height_m, max_devices)
VALUES ('Tecsys', 915.0, 21.0, 0.0, -120.0, 6.0, 5000)
ON CONFLICT (name) DO NOTHING;

UPDATE gateway_profiles
   SET is_default = TRUE, antenna_gain_dbi = 0.0, sensor_height_m = 5.0, active = TRUE
 WHERE name = 'Tecsys';

CREATE UNIQUE INDEX IF NOT EXISTS uq_gateway_profiles_padrao ON gateway_profiles (is_default) WHERE is_default;
