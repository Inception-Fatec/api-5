-- Índices espaciais (GiST) para as colunas geometry
CREATE INDEX idx_sub_geom       ON sub       USING GIST (geom);
CREATE INDEX idx_untrat_geom    ON untrat    USING GIST (geom);
CREATE INDEX idx_untrmt_geom    ON untrmt    USING GIST (geom);
CREATE INDEX idx_ssdat_geom     ON ssdat     USING GIST (geom);
CREATE INDEX idx_ssdmt_geom     ON ssdmt     USING GIST (geom);
CREATE INDEX idx_ssdbt_geom     ON ssdbt     USING GIST (geom);
CREATE INDEX idx_ucat_pj_geom   ON ucat_pj   USING GIST (geom);
CREATE INDEX idx_ucmt_pj_geom   ON ucmt_pj   USING GIST (geom);
CREATE INDEX idx_ucbt_geom      ON ucbt      USING GIST (geom);
CREATE INDEX idx_ucbt_raw_geom  ON ucbt_raw  USING GIST (geom);
CREATE INDEX idx_project_history_polygon ON project_history USING GIST (polygon);

-- Índices nas chaves estrangeiras mais consultadas
CREATE INDEX idx_projects_created_by      ON projects (created_by);
CREATE INDEX idx_project_history_project  ON project_history (project_id);
CREATE INDEX idx_etl_jobs_created_by      ON etl_jobs (created_by);
CREATE INDEX idx_untrat_sub               ON untrat (sub);
CREATE INDEX idx_untrmt_sub               ON untrmt (sub);
CREATE INDEX idx_untrmt_uni_tr_at         ON untrmt (uni_tr_at);
CREATE INDEX idx_ucbt_sub                 ON ucbt (sub);
CREATE INDEX idx_ucbt_uni_tr_mt           ON ucbt (uni_tr_mt);
CREATE INDEX idx_ucmt_pj_sub              ON ucmt_pj (sub);
CREATE INDEX idx_ucat_pj_sub              ON ucat_pj (sub);
