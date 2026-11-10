CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE external_points (
    id          BIGSERIAL PRIMARY KEY,
    dist        VARCHAR(100) NOT NULL,
    mun         VARCHAR(10)  NOT NULL,
    external_id VARCHAR(100) NOT NULL,
    papel       VARCHAR(20)  NOT NULL,
    descricao   TEXT,
    geom        geometry(Point, 4674) NOT NULL,
    created_by  BIGINT REFERENCES users(id),
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,

    CONSTRAINT uq_external_points_dist_external_id UNIQUE (dist, external_id),
    CONSTRAINT ck_external_points_papel
        CHECK (papel IN ('candidato', 'ponto_a_cobrir', 'interesse'))
);

CREATE INDEX idx_external_points_geom ON external_points USING GIST (geom);
CREATE INDEX idx_external_points_dist_mun ON external_points (dist, mun);