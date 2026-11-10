ALTER TABLE projects ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE;

UPDATE projects SET updated_at = created_at WHERE updated_at IS NULL;