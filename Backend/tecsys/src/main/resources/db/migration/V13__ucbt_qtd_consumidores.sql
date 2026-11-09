-- #TG-144: baixa tensão agregada por ponto de conexão + classe + CNAE.
-- Cada registro de ucbt passa a representar qtd_consumidores consumidores (o
-- motor usa como peso). Registros antigos (um por consumidor, vindos do CSV
-- da ANEEL) continuam valendo com o padrão 1.
ALTER TABLE ucbt ADD COLUMN IF NOT EXISTS qtd_consumidores INTEGER NOT NULL DEFAULT 1;
