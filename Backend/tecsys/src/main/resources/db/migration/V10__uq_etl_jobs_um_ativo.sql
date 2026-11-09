-- #TG-105: no máximo um ETL ativo (PENDING ou RUNNING) por vez.
-- O EtlService trata a violação deste índice como "Já existe um ETL em andamento".
-- IF NOT EXISTS: no Supabase o índice já foi criado à mão com a mesma definição.
CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_jobs_um_ativo
    ON etl_jobs ((true))
    WHERE status IN ('PENDING', 'RUNNING');
