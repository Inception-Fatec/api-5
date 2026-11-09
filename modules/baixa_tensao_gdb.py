"""Baixa tensão lida da própria geodatabase, agregada por ponto de conexão (#TG-144).

A .gdb traz todos os consumidores de baixa tensão (inclusive residenciais) em
UCBT_tab, e cada um aponta (PN_CON) para um ponto com coordenada em PONNOT.
Gravar um registro por consumidor não cabe no Supabase gratuito (EDP ES ≈
780 MB), mas os consumidores do mesmo ponto têm a mesma coordenada: grava-se
um registro por ponto + classe + CNAE, com a quantidade de consumidores
(qtd_consumidores), que o motor usa como peso. Os filtros do app (município,
bairro, subestação, conjunto, classe e CNAE) continuam valendo.

Substitui o caminho antigo (CSV nacional da ANEEL carregado pelo
preload_ucbt.py), que só tinha consumidores não residenciais.
"""
import logging

import geopandas as gpd
import pandas as pd
import pyogrio
from sqlalchemy import text

from etl_common import CRS_ALVO, Metricas, prefixar

logger = logging.getLogger("etl.bt")

COLUNAS_UC = ["PN_CON", "UNI_TR_MT", "CTMT", "CONJ", "MUN", "BRR", "CLAS_SUB", "CNAE",
              "SIT_ATIV", "CAR_INST", "ARE_LOC", "TIP_SIST"]
CHAVE_GRUPO = ["PN_CON", "CLAS_SUB", "CNAE"]
LOTE_PONTOS = 500
# Margem (graus, ~2 km) em volta dos municípios: ponto de conexão fora disso é erro
# de cadastro (ex.: consumidor de Vitória com coordenada em Cachoeiro, a 98 km).
# Menos que isso descartaria consumidores legítimos na divisa de municípios rurais,
# onde o limite do IBGE e o cadastro da distribuidora diferem (Aracruz: ~140 pontos
# entre 0,5 e 2 km fora).
MARGEM_MUNICIPIO_GRAUS = 0.02

AVISO_SEM_BT_NO_ARQUIVO = (
    "Baixa tensão não carregada: a geodatabase não tem consumidores de baixa tensão ativos "
    "nesses municípios (camada UCBT_tab)."
)


def _texto(serie: pd.Series) -> pd.Series:
    s = serie.astype("string").str.strip()
    return s.mask(s == "")


def _ler_consumidores(gdb, municipios: list[str]) -> pd.DataFrame:
    lista = ", ".join(f"'{m}'" for m in municipios)  # códigos já validados (7 dígitos)
    return pyogrio.read_dataframe(gdb, layer="UCBT_tab", columns=COLUNAS_UC,
                                  read_geometry=False, where=f"MUN IN ({lista})")


def _ler_pontos(gdb, municipios: list[str], codigos: set) -> gpd.GeoDataFrame:
    """Pontos de conexão (PONNOT) dos consumidores: primeiro pelos municípios e,
    para os que ficaram de fora (ponto cadastrado em município vizinho), pelo código."""
    lista = ", ".join(f"'{m}'" for m in municipios)
    pontos = pyogrio.read_dataframe(gdb, layer="PONNOT", columns=["COD_ID", "MUN"], where=f"MUN IN ({lista})")
    pontos = pontos[pontos["COD_ID"].isin(codigos)][["COD_ID", "geometry"]]

    faltando = sorted(codigos - set(pontos["COD_ID"]))
    partes = [pontos]
    for i in range(0, len(faltando), LOTE_PONTOS):
        lote = ", ".join("'" + str(c).replace("'", "''") + "'" for c in faltando[i:i + LOTE_PONTOS])
        extra = pyogrio.read_dataframe(gdb, layer="PONNOT", columns=["COD_ID"], where=f"COD_ID IN ({lote})")
        partes.append(extra[["COD_ID", "geometry"]])
    todos = gpd.GeoDataFrame(pd.concat(partes, ignore_index=True), geometry="geometry", crs=pontos.crs)
    return todos.drop_duplicates(subset="COD_ID")


def agregar_por_ponto(uc: pd.DataFrame) -> pd.DataFrame:
    """Um registro por ponto de conexão + classe + CNAE, com a quantidade de consumidores."""
    uc = uc.copy()
    for c in COLUNAS_UC:
        if c != "CAR_INST":
            uc[c] = _texto(uc[c])
    uc = uc[uc["SIT_ATIV"].str.upper() == "AT"]
    uc = uc[uc["PN_CON"].notna()]
    uc["CLAS_SUB"] = uc["CLAS_SUB"].fillna("")
    uc["CNAE"] = uc["CNAE"].fillna("")
    uc["CAR_INST"] = pd.to_numeric(uc["CAR_INST"], errors="coerce")

    g = (uc.groupby(CHAVE_GRUPO, sort=False)
           .agg(qtd_consumidores=("PN_CON", "size"),
                car_inst=("CAR_INST", "sum"),
                uni_tr_mt=("UNI_TR_MT", "first"),
                ctmt=("CTMT", "first"),
                conj=("CONJ", "first"),
                mun=("MUN", "first"),
                brr=("BRR", "first"),
                are_loc=("ARE_LOC", "first"),
                tip_sist=("TIP_SIST", "first"))
           .reset_index())
    g["cod_id_encr"] = g["PN_CON"] + "|" + g["CLAS_SUB"] + "|" + g["CNAE"]
    g["clas_sub"] = g["CLAS_SUB"].mask(g["CLAS_SUB"] == "")
    g["cnae"] = g["CNAE"].mask(g["CNAE"] == "")
    return g


def carregar_baixa_tensao(conn, gdb, dist: str, prefixo: str, municipios: list[str],
                          metricas: Metricas, area=None) -> str | None:
    """Substitui a baixa tensão da distribuidora nesses municípios pela da .gdb.
    Devolve um aviso quando não há consumidores BT no arquivo, ou None."""
    uc = _ler_consumidores(gdb, municipios)
    g = agregar_por_ponto(uc)
    ativos = int(g["qtd_consumidores"].sum()) if not g.empty else 0
    metricas.add("ucbt", consumidores_lidos=len(uc), consumidores_ativos=ativos,
                 pontos_conexao=int(g["PN_CON"].nunique()) if not g.empty else 0, registros=len(g))
    if g.empty:
        metricas.add("ucbt", inseridos=0, consumidores_gravados=0, sem_transformador=0)
        return AVISO_SEM_BT_NO_ARQUIVO

    pontos = _ler_pontos(gdb, municipios, set(g["PN_CON"]))
    g = g.merge(pontos.rename(columns={"COD_ID": "PN_CON"}), on="PN_CON", how="left")
    sem_coordenada = int(g["geometry"].isna().sum())
    g = g[g["geometry"].notna()]
    metricas.add("ucbt", sem_coordenada=sem_coordenada)

    if area is not None:
        # area: limites dos municípios (IBGE) no CRS de destino, o mesmo do recorte da rede
        limite = gpd.GeoSeries([area], crs=CRS_ALVO).buffer(MARGEM_MUNICIPIO_GRAUS).iloc[0]
        geoms = gpd.GeoSeries(g["geometry"].values, crs=pontos.crs or CRS_ALVO)
        if geoms.crs.to_string() != CRS_ALVO:
            geoms = geoms.to_crs(CRS_ALVO)
        dentro = geoms.within(limite).values
        fora = g[~dentro]
        if len(fora):
            logger.warning("Baixa tensão: %s registro(s) (%s consumidores) com coordenada fora do município "
                           "descartados (erro de cadastro na BDGD).", len(fora), int(fora["qtd_consumidores"].sum()))
        metricas.add("ucbt", fora_do_municipio=len(fora),
                     consumidores_fora_do_municipio=int(fora["qtd_consumidores"].sum()))
        g = g[dentro]

    gdf = gpd.GeoDataFrame(
        g[["cod_id_encr", "mun", "brr", "uni_tr_mt", "ctmt", "conj", "clas_sub", "cnae",
           "car_inst", "tip_sist", "are_loc", "qtd_consumidores", "geometry"]],
        geometry="geometry", crs=pontos.crs or CRS_ALVO,
    ).rename_geometry("geom")
    if gdf.crs is not None and gdf.crs.to_string() != CRS_ALVO:
        gdf = gdf.to_crs(CRS_ALVO)
    prefixar(gdf, prefixo, colunas=("cod_id_encr", "uni_tr_mt", "ctmt"))

    staging = "_stg_ucbt_gdb"
    gdf.to_postgis(staging, conn, if_exists="replace", index=False)

    # Substitui: a BT desses municípios da distribuidora (inclusive a que veio do
    # CSV da ANEEL, um registro por consumidor) dá lugar à agregada da .gdb.
    removidos = conn.execute(
        text("""
            DELETE FROM ucbt u USING sub s
            WHERE u.sub = s.cod_id AND s.dist = :dist AND u.mun = ANY(:municipios)
        """),
        {"dist": dist, "municipios": municipios},
    ).rowcount

    # Subestação e transformador de AT vêm do transformador de MT já carregado
    # (garante as FKs); consumidor sem transformador na rede carregada fica de fora.
    inseridos, consumidores = conn.execute(text(f"""
        WITH ins AS (
            INSERT INTO ucbt (cod_id_encr, mun, brr, sub, uni_tr_at, uni_tr_mt, conj, ctmt, clas_sub,
                              cnae, car_inst, tip_sist, are_loc, qtd_consumidores, geom)
            SELECT st.cod_id_encr, left(st.mun, 10), left(st.brr, 60), t.sub, t.uni_tr_at, t.cod_id,
                   left(st.conj, 20), left(st.ctmt, 40), left(st.clas_sub, 10), left(st.cnae, 10),
                   st.car_inst, left(st.tip_sist, 15), left(st.are_loc, 5), st.qtd_consumidores, st.geom
            FROM "{staging}" st
            JOIN untrmt t ON t.cod_id = st.uni_tr_mt
            ON CONFLICT (cod_id_encr) DO NOTHING
            RETURNING qtd_consumidores
        )
        SELECT count(*), coalesce(sum(qtd_consumidores), 0) FROM ins
    """)).one()
    conn.execute(text(f'DROP TABLE "{staging}"'))

    metricas.add("ucbt", substituidos=removidos, inseridos=int(inseridos),
                 consumidores_gravados=int(consumidores),
                 sem_transformador=len(gdf) - int(inseridos))
    logger.info("Baixa tensão: %s consumidores ativos em %s registros; %s gravados (%s consumidores).",
                ativos, len(g), inseridos, consumidores)
    return None
