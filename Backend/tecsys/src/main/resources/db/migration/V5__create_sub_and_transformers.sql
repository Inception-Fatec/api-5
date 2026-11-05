CREATE TABLE sub (
    cod_id  VARCHAR   NOT NULL,
    nome    VARCHAR   NULL,
    dist    VARCHAR   NULL,
    geom    GEOMETRY  NULL,
    CONSTRAINT pk_sub PRIMARY KEY (cod_id)
);

CREATE TABLE untrat (
    cod_id   VARCHAR   NOT NULL,
    sub      VARCHAR   NULL,
    conj     VARCHAR   NULL,
    mun      VARCHAR   NULL,
    are_loc  VARCHAR   NULL,
    pot_nom  NUMERIC   NULL,
    geom     GEOMETRY  NULL,
    CONSTRAINT pk_untrat PRIMARY KEY (cod_id),
    CONSTRAINT fk_untrat_sub FOREIGN KEY (sub) REFERENCES sub (cod_id)
);

CREATE TABLE untrmt (
    cod_id        VARCHAR   NOT NULL,
    sub           VARCHAR   NULL,
    uni_tr_at     VARCHAR   NULL,
    ctmt          VARCHAR   NULL,
    conj          VARCHAR   NULL,
    mun           VARCHAR   NULL,
    are_loc       VARCHAR   NULL,
    posto         VARCHAR   NULL,
    pot_nom       NUMERIC   NULL,
    ten_lin_se    NUMERIC   NULL,
    geom          GEOMETRY  NULL,
    CONSTRAINT pk_untrmt PRIMARY KEY (cod_id),
    CONSTRAINT fk_untrmt_sub FOREIGN KEY (sub) REFERENCES sub (cod_id),
    CONSTRAINT fk_untrmt_uni_tr_at FOREIGN KEY (uni_tr_at) REFERENCES untrat (cod_id)
);
