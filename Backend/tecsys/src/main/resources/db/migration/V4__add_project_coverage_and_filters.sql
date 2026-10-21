ALTER TABLE project_history ADD COLUMN filter_params JSONB;

CREATE TABLE project_coverage (
    project_id BIGINT NOT NULL,
    summary JSONB,
    gateways JSONB,
    points JSONB,
    CONSTRAINT pk_project_coverage PRIMARY KEY (project_id),
    CONSTRAINT fk_project_coverage_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
);