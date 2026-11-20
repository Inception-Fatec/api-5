-- Versão em uso do projeto. Voltar para uma versão antiga só troca este
-- ponteiro (não cria versão nova). Nulo = a versão mais recente, como antes.
ALTER TABLE projects ADD COLUMN IF NOT EXISTS current_version_id BIGINT NULL
    REFERENCES project_history (id) ON DELETE SET NULL;
