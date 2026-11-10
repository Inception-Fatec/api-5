-- #TG-87: atividade mais recente do projeto (criar, recalcular ou abrir o
-- relatório), para a seção "Recentes" da tela de projetos.
ALTER TABLE projects ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ NULL;
UPDATE projects SET last_activity_at = created_at WHERE last_activity_at IS NULL;
ALTER TABLE projects ALTER COLUMN last_activity_at SET DEFAULT now();
ALTER TABLE projects ALTER COLUMN last_activity_at SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_projects_last_activity ON projects (last_activity_at DESC);
