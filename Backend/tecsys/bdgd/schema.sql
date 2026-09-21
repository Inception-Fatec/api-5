CREATE EXTENSION IF NOT EXISTS postgis;


-- ============================================
-- SUB
-- ============================================

CREATE TABLE IF NOT EXISTS sub (
    cod_id TEXT PRIMARY KEY,
    nome TEXT,
    dist TEXT,
    geom geometry(Geometry, 4674)
);


-- ============================================
-- UNTRAT
-- ============================================

CREATE TABLE IF NOT EXISTS untrat (
    cod_id TEXT PRIMARY KEY,

    sub TEXT,
    conj TEXT,
    mun TEXT,
    are_loc TEXT,
    pot_nom NUMERIC,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_untrat_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id)
);


-- ============================================
-- UNTRMT
-- ============================================

CREATE TABLE IF NOT EXISTS untrmt (
    cod_id TEXT PRIMARY KEY,

    sub TEXT,
    uni_tr_at TEXT,

    ctmt TEXT,
    conj TEXT,
    mun TEXT,
    are_loc TEXT,
    posto TEXT,

    pot_nom NUMERIC,
    ten_lin_se NUMERIC,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_untrmt_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id),

    CONSTRAINT fk_untrmt_untrat
        FOREIGN KEY (uni_tr_at)
        REFERENCES untrat(cod_id)
);


-- ============================================
-- SSDAT
-- ============================================

CREATE TABLE IF NOT EXISTS ssdat (
    cod_id TEXT PRIMARY KEY,

    sub TEXT,
    conj TEXT,
    ctat TEXT,
    are_loc TEXT,
    tip_inst TEXT,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_ssdat_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id)
);


-- ============================================
-- SSDMT
-- ============================================

CREATE TABLE IF NOT EXISTS ssdmt (
    cod_id TEXT PRIMARY KEY,

    sub TEXT,
    uni_tr_at TEXT,

    ctmt TEXT,
    conj TEXT,
    are_loc TEXT,
    tip_inst TEXT,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_ssdmt_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id),

    CONSTRAINT fk_ssdmt_untrat
        FOREIGN KEY (uni_tr_at)
        REFERENCES untrat(cod_id)
);


-- ============================================
-- SSDBT
-- ============================================

CREATE TABLE IF NOT EXISTS ssdbt (
    cod_id TEXT PRIMARY KEY,

    sub TEXT,
    uni_tr_at TEXT,
    uni_tr_mt TEXT,

    ctmt TEXT,
    conj TEXT,
    are_loc TEXT,
    tip_inst TEXT,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_ssdbt_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id),

    CONSTRAINT fk_ssdbt_untrat
        FOREIGN KEY (uni_tr_at)
        REFERENCES untrat(cod_id),

    CONSTRAINT fk_ssdbt_untrmt
        FOREIGN KEY (uni_tr_mt)
        REFERENCES untrmt(cod_id)
);


-- ============================================
-- UCAT_PJ
-- ============================================

CREATE TABLE IF NOT EXISTS ucat_pj (
    cod_id_encr TEXT PRIMARY KEY,

    mun TEXT,
    brr TEXT,

    sub TEXT,

    conj TEXT,
    ctat TEXT,
    clas_sub TEXT,
    cnae TEXT,

    car_inst NUMERIC(15,3),
    dem_cont NUMERIC(15,3),

    tip_sist TEXT,
    are_loc TEXT,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_ucat_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id)
);


-- ============================================
-- UCMT_PJ
-- ============================================

CREATE TABLE IF NOT EXISTS ucmt_pj (
    cod_id_encr TEXT PRIMARY KEY,

    mun TEXT,
    brr TEXT,

    sub TEXT,
    uni_tr_at TEXT,

    conj TEXT,
    ctmt TEXT,

    clas_sub TEXT,
    cnae TEXT,

    car_inst NUMERIC(15,3),
    dem_cont NUMERIC(15,3),

    tip_sist TEXT,
    are_loc TEXT,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_ucmt_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id),

    CONSTRAINT fk_ucmt_untrat
        FOREIGN KEY (uni_tr_at)
        REFERENCES untrat(cod_id)
);


-- ============================================
-- UCBT
-- ============================================

CREATE TABLE IF NOT EXISTS ucbt (
    cod_id_encr TEXT PRIMARY KEY,

    mun TEXT,
    brr TEXT,

    sub TEXT,
    uni_tr_at TEXT,
    uni_tr_mt TEXT,

    conj TEXT,
    ctmt TEXT,

    clas_sub TEXT,
    cnae TEXT,

    car_inst NUMERIC(15,3),

    tip_sist TEXT,
    are_loc TEXT,

    geom geometry(Geometry, 4674),

    CONSTRAINT fk_ucbt_sub
        FOREIGN KEY (sub)
        REFERENCES sub(cod_id),

    CONSTRAINT fk_ucbt_untrat
        FOREIGN KEY (uni_tr_at)
        REFERENCES untrat(cod_id),

    CONSTRAINT fk_ucbt_untrmt
        FOREIGN KEY (uni_tr_mt)
        REFERENCES untrmt(cod_id)
);
