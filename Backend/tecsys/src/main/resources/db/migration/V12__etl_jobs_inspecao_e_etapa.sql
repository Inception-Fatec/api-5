-- #TG-143: upload em duas etapas (inspeção da .gdb -> escolha dos municípios)
-- e etapa atual da carga para a tela.
--   inspection_json: distribuidora, período e municípios presentes no arquivo
--   work_dir:        pasta temporária do upload enquanto aguarda a escolha
--   stage:           texto da etapa atual anunciada pelo ETL
ALTER TABLE etl_jobs ADD COLUMN IF NOT EXISTS inspection_json TEXT NULL;
ALTER TABLE etl_jobs ADD COLUMN IF NOT EXISTS work_dir VARCHAR(500) NULL;
ALTER TABLE etl_jobs ADD COLUMN IF NOT EXISTS stage VARCHAR(120) NULL;
