-- #TG-141: tamanho do arquivo enviado, para o histórico de cargas mostrar o
-- tamanho mesmo depois de recarregar a página. Nulo nas cargas antigas.
ALTER TABLE etl_jobs ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT NULL;
