-- #TG-84: motivo da falha do cálculo (ex.: motor fora do ar), para a tela
-- mostrar junto com o status FALHA. Nulo nos demais status.
ALTER TABLE projects ADD COLUMN IF NOT EXISTS status_message VARCHAR(500) NULL;
