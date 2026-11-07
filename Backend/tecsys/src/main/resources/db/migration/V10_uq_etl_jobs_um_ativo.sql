CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_jobs_um_ativo
    ON etl_jobs (...)          -- colunas exatamente como no indexdef
    WHERE (...);               -- predicado exatamente como no indexdef