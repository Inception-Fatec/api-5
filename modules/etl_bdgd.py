import logging
import os
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import Point
from sqlalchemy import create_engine

DB_URL = os.getenv("DB_URL")

CSV_UCAT_PJ_URL = "https://dadosabertos.aneel.gov.br/dataset/4459e483-451f-4444-8022-bd8b5eac05c5/resource/4318d38a-0bcd-421d-afb1-fb88b0c92a87/download/ucat_pj.csv"
CSV_UCMT_PJ_URL = "https://dadosabertos.aneel.gov.br/dataset/4459e483-451f-4444-8022-bd8b5eac05c5/resource/f6671cba-f269-42ef-8eb3-62cb3bfa0b98/download/ucmt_pj.csv"
CSV_UCBT_PJ_URL = "https://dadosabertos.aneel.gov.br/dataset/4459e483-451f-4444-8022-bd8b5eac05c5/resource/3ae4d382-7072-4b08-90a4-dcd187a2eae2/download/ucbt_pj.zip"
CRS_ALVO = "EPSG:4674"

CHUNK_SIZE = 200_000

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("etl_bdgd")

def verificar_cobertura(engine, municipios: list[str] | None, distribuidoras: list[str] | None) -> bool:

    if distribuidoras:
        lista = ", ".join(f"'{d}'" for d in distribuidoras)
        count = pd.read_sql(f"SELECT COUNT(*) AS n FROM sub WHERE dist IN ({lista})", engine)["n"][0]
        if count == 0:
            return False

    if municipios:
        lista = ", ".join(f"'{m}'" for m in municipios)
        query = f"""SELECT COUNT(*) AS n FROM (
                        SELECT mun FROM untrat WHERE mun IN ({lista}) 
                        UNION 
                        SELECT mun FROM untrmt WHERE mun IN ({lista})
                    ) t"""
        count = pd.read_sql(query, engine)["n"][0]
        if count == 0:
            return False
    return True

def municipios_pendentes(engine, tabela: str, municipios: list[str]) -> list[str]:

    if not municipios:
        return []
    
    lista = ", ".join(f"'{m}'" for m in municipios)
    query = f"SELECT DISTINCT mun FROM {tabela} WHERE mun IN ({lista})"
    ja_carregados = set(pd.read_sql(query, engine)["mun"].astype(str))
    pendentes = [m for m in municipios if m not in ja_carregados]

    if ja_carregados:
        logger.info(f"'{tabela}': Municipios já carregados, serão pulados: {sorted(ja_carregados)}")

    return pendentes

def extrair_csv(fonte, municipios: list[str] | None, distribuidoras: list[str] | None, chunksize: int = CHUNK_SIZE) -> pd.DataFrame:

    partes = []
    leitor = pd.read_csv(fonte, sep=";", encoding="latin-1", chunksize=chunksize)
    for i, pedaco in enumerate(leitor, start=1):
        mascara = pd.Series(True, index = pedaco.index)
        if municipios:
            mascara &= pedaco["MUN"].astype(str).isin(municipios)
        if distribuidoras:
            mascara &= pedaco["DIST"].astype(str).isin(distribuidoras)

        pedaco = pedaco[mascara]
        pedaco = pedaco[pedaco["SIT_ATIV"] == "AT"]

        if not pedaco.empty:
            partes.append(pedaco)
        logger.info(f"  chunk {i}: {len(pedaco)} registros retidos")

    return pd.concat(partes, ignore_index=True) if partes else pd.DataFrame()

def para_geodataframe(df: pd.DataFrame) -> gpd.GeoDataFrame:
    geometry = [Point(xy) for xy in zip(df["point_x"], df["point_y"])]
    gdf = gpd.GeoDataFrame(df, geometry=geometry, crs=CRS_ALVO)
    gdf = gdf.drop(columns=["point_x", "point_y"])
    return gdf.rename_geometry("geom")


def limpar_ucat(df: pd.DataFrame, engine = None) -> gpd.GeoDataFrame:
    colunas = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "CONJ", "CTAT", "CLAS_SUB",
               "CNAE", "CAR_INST", "DEM_CONT", "TIP_SIST", "ARE_LOC",
               "POINT_X", "POINT_Y"]
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
    return para_geodataframe(df)


def limpar_ucmt(df: pd.DataFrame, engine = None) -> gpd.GeoDataFrame:
    colunas = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "UNI_TR_AT", "CONJ", "CTMT",
               "CLAS_SUB", "CNAE", "CAR_INST", "DEM_CONT", "TIP_SIST", "ARE_LOC",
               "POINT_X", "POINT_Y"]
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
    return para_geodataframe(df)


def limpar_ucbt(df: pd.DataFrame, engine) -> gpd.GeoDataFrame:

    colunas = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "UNI_TR_AT", "UNI_TR_MT",
               "CONJ", "CTMT", "CLAS_SUB", "CNAE", "CAR_INST", "TIP_SIST",
               "ARE_LOC", "POINT_X", "POINT_Y"]
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
 
    tem_coord = df["point_x"].notna() & df["point_y"].notna()
    df["geom"] = None
    df.loc[tem_coord, "geom"] = [
        Point(xy) for xy in zip(df.loc[tem_coord, "point_x"], df.loc[tem_coord, "point_y"])
    ]
 
    sem_coord = ~tem_coord
    if sem_coord.any():
        codigos = df.loc[sem_coord, "uni_tr_mt"].dropna().astype(str).unique().tolist()
        lista = ", ".join(f"'{c}'" for c in codigos) or "''"
        transf = gpd.read_postgis(
            f"SELECT cod_id, geom FROM untrmt WHERE cod_id IN ({lista})", engine, geom_col="geom", crs=CRS_ALVO
        ).set_index("cod_id")["geom"]
        df.loc[sem_coord, "geom"] = df.loc[sem_coord, "uni_tr_mt"].astype(str).map(transf)
 
    sem_geom = df["geom"].isna()
    if sem_geom.any():
        logger.warning(f"UCBT: {sem_geom.sum()} registro(s) sem coordenada e sem transformador MT localizado — descartados")
        df = df[~sem_geom]
 
    return gpd.GeoDataFrame(df.drop(columns=["point_x", "point_y"]), geometry="geom", crs=CRS_ALVO)

def carregar(gdf: gpd.GeoDataFrame, tabela: str, engine) -> None:
    gdf.to_postgis(tabela, engine, if_exists="append", index=False)
    logger.info(f"  -> {len(gdf)} registros carregados em '{tabela}'")


def main(municipios: list[str] | None = None, distribuidoras: list[str] | None = None) -> dict:

    if not municipios and not distribuidoras:
        raise ValueError("Informe ao menos um critério de busca: municipios ou ditribuidoras.")

    engine = create_engine(DB_URL)

    logger.info("0) Verificando cobertura no banco...")
    if not verificar_cobertura(engine, municipios, distribuidoras):
        logger.warning("Região ainda não disponivel - malha elétrica não carregada para essa seleção.")
        return {"status": "indisponivel"}

    tabelas = [
        (CSV_UCAT_PJ_URL, "ucat_pj", limpar_ucat),
        (CSV_UCMT_PJ_URL, "ucmt_pj", limpar_ucmt),
        (CSV_UCBT_PJ_URL, "ucbt", limpar_ucbt),
    ]
 
    for i, (url, tabela, limpar_fn) in enumerate(tabelas, start=1):
        logger.info(f"{i}) Processando '{tabela}'...")
        pendentes = municipios_pendentes(engine, tabela, municipios)
        if not pendentes:
            logger.info(f"'{tabela}': nenhum município pendente — pulando.")
            continue
 
        df = extrair_csv(url, pendentes, distribuidoras)
        gdf = limpar_fn(df, engine)
        carregar(gdf, tabela, engine)

    logger.info("ETL concluído.")
    return {"status": "concluido"}