-- #120: a camada SSDAT da BDGD não tem o campo SUB, então a distribuidora
-- é gravada direto na linha (mesmo valor cru de sub.dist).
-- Sem backfill aqui: o banco tem mais de uma distribuidora e a SSDAT antiga
-- está com sub nulo, então não há como saber de quem é cada linha. O
-- preenchimento é feito pelo ETL quando o arquivo da distribuidora é reenviado.
ALTER TABLE ssdat ADD COLUMN IF NOT EXISTS dist VARCHAR NULL;
CREATE INDEX IF NOT EXISTS idx_ssdat_dist ON ssdat (dist);