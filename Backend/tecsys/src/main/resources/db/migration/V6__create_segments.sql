CREATE TABLE ssdat (
    cod_id    VARCHAR   NOT NULL,
    sub       VARCHAR   NULL,
    conj      VARCHAR   NULL,
    ctat      VARCHAR   NULL,
    are_loc   VARCHAR   NULL,
    tip_inst  VARCHAR   NULL,
    geom      GEOMETRY  NULL,
    CONSTRAINT pk_ssdat PRIMARY KEY (cod_id),
    CONSTRAINT fk_ssdat_sub FOREIGN KEY (sub) REFERENCES sub (cod_id)
);

CREATE TABLE ssdmt (
    cod_id     VARCHAR   NOT NULL,
    sub        VARCHAR   NULL,
    uni_tr_at  VARCHAR   NULL,
    ctmt       VARCHAR   NULL,
    conj       VARCHAR   NULL,
    are_loc    VARCHAR   NULL,
    tip_inst   VARCHAR   NULL,
    geom       GEOMETRY  NULL,
    CONSTRAINT pk_ssdmt PRIMARY KEY (cod_id),
    CONSTRAINT fk_ssdmt_sub FOREIGN KEY (sub) REFERENCES sub (cod_id),
    CONSTRAINT fk_ssdmt_uni_tr_at FOREIGN KEY (uni_tr_at) REFERENCES untrat (cod_id)
);

CREATE TABLE ssdbt (
    cod_id     VARCHAR   NOT NULL,
    sub        VARCHAR   NULL,
    uni_tr_at  VARCHAR   NULL,
    uni_tr_mt  VARCHAR   NULL,
    ctmt       VARCHAR   NULL,
    conj       VARCHAR   NULL,
    are_loc    VARCHAR   NULL,
    tip_inst   VARCHAR   NULL,
    geom       GEOMETRY  NULL,
    CONSTRAINT pk_ssdbt PRIMARY KEY (cod_id),
    CONSTRAINT fk_ssdbt_sub FOREIGN KEY (sub) REFERENCES sub (cod_id),
    CONSTRAINT fk_ssdbt_uni_tr_at FOREIGN KEY (uni_tr_at) REFERENCES untrat (cod_id),
    CONSTRAINT fk_ssdbt_uni_tr_mt FOREIGN KEY (uni_tr_mt) REFERENCES untrmt (cod_id)
);
