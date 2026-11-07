CREATE TABLE ucat_pj (
    cod_id_encr  VARCHAR   NOT NULL,
    mun          VARCHAR   NULL,
    brr          VARCHAR   NULL,
    sub          VARCHAR   NULL,
    conj         VARCHAR   NULL,
    ctat         VARCHAR   NULL,
    clas_sub     VARCHAR   NULL,
    cnae         VARCHAR   NULL,
    car_inst     NUMERIC   NULL,
    dem_cont     NUMERIC   NULL,
    tip_sist     VARCHAR   NULL,
    are_loc      VARCHAR   NULL,
    geom         GEOMETRY  NULL,
    CONSTRAINT pk_ucat_pj PRIMARY KEY (cod_id_encr),
    CONSTRAINT fk_ucat_pj_sub FOREIGN KEY (sub) REFERENCES sub (cod_id)
);

CREATE TABLE ucmt_pj (
    cod_id_encr  VARCHAR   NOT NULL,
    mun          VARCHAR   NULL,
    brr          VARCHAR   NULL,
    sub          VARCHAR   NULL,
    uni_tr_at    VARCHAR   NULL,
    conj         VARCHAR   NULL,
    ctmt         VARCHAR   NULL,
    clas_sub     VARCHAR   NULL,
    cnae         VARCHAR   NULL,
    car_inst     NUMERIC   NULL,
    dem_cont     NUMERIC   NULL,
    tip_sist     VARCHAR   NULL,
    are_loc      VARCHAR   NULL,
    geom         GEOMETRY  NULL,
    CONSTRAINT pk_ucmt_pj PRIMARY KEY (cod_id_encr),
    CONSTRAINT fk_ucmt_pj_sub FOREIGN KEY (sub) REFERENCES sub (cod_id),
    CONSTRAINT fk_ucmt_pj_uni_tr_at FOREIGN KEY (uni_tr_at) REFERENCES untrat (cod_id)
);

CREATE TABLE ucbt (
    cod_id_encr  VARCHAR   NOT NULL,
    mun          VARCHAR   NULL,
    brr          VARCHAR   NULL,
    sub          VARCHAR   NULL,
    uni_tr_at    VARCHAR   NULL,
    uni_tr_mt    VARCHAR   NULL,
    conj         VARCHAR   NULL,
    ctmt         VARCHAR   NULL,
    clas_sub     VARCHAR   NULL,
    cnae         VARCHAR   NULL,
    car_inst     NUMERIC   NULL,
    tip_sist     VARCHAR   NULL,
    are_loc      VARCHAR   NULL,
    geom         GEOMETRY  NULL,
    CONSTRAINT pk_ucbt PRIMARY KEY (cod_id_encr),
    CONSTRAINT fk_ucbt_sub FOREIGN KEY (sub) REFERENCES sub (cod_id),
    CONSTRAINT fk_ucbt_uni_tr_at FOREIGN KEY (uni_tr_at) REFERENCES untrat (cod_id),
    CONSTRAINT fk_ucbt_uni_tr_mt FOREIGN KEY (uni_tr_mt) REFERENCES untrmt (cod_id)
);

-- Tabela de staging (sem FKs, chave composta, tipos text)
CREATE TABLE ucbt_raw (
    dist         TEXT      NOT NULL,
    cod_id_encr  TEXT      NOT NULL,
    mun          TEXT      NULL,
    brr          TEXT      NULL,
    sub          TEXT      NULL,
    uni_tr_at    TEXT      NULL,
    uni_tr_mt    TEXT      NULL,
    conj         TEXT      NULL,
    ctmt         TEXT      NULL,
    clas_sub     TEXT      NULL,
    cnae         TEXT      NULL,
    car_inst     NUMERIC   NULL,
    tip_sist     TEXT      NULL,
    are_loc      TEXT      NULL,
    geom         GEOMETRY  NULL,
    CONSTRAINT pk_ucbt_raw PRIMARY KEY (dist, cod_id_encr)
);
