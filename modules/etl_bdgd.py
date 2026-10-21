import logging
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import geopandas as gpd
import pandas as pd
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.csv as pacsv
import requests
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

from etl_common import (
    CRS_ALVO,
    CRS_ORIGEM_BDGD,
    Metricas,
    anular_fk_orfas,
    carregar_idempotente,
    prefixar,
    validar_municipios,
)

load_dotenv()

CSV_UCAT_PJ_URL = "https://dadosabertos.aneel.gov.br/dataset/4459e483-451f-4444-8022-bd8b5eac05c5/resource/4318d38a-0bcd-421d-afb1-fb88b0c92a87/download/ucat_pj.csv"
CSV_UCMT_PJ_URL = "https://dadosabertos.aneel.gov.br/dataset/4459e483-451f-4444-8022-bd8b5eac05c5/resource/f6671cba-f269-42ef-8eb3-62cb3bfa0b98/download/ucmt_pj.csv"

CACHE_DIR = Path(os.getenv("CACHE_DIR", "cache_aneel"))
BLOCK_SIZE = 64 << 20
MAX_WORKERS = 2

COLUNAS_UCAT = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "CONJ", "CTAT", "CLAS_SUB",
                "CNAE", "CAR_INST", "DEM_CONT", "TIP_SIST", "ARE_LOC",
                "POINT_X", "POINT_Y"]

COLUNAS_UCMT = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "UNI_TR_AT", "CONJ", "CTMT",
                "CLAS_SUB", "CNAE", "CAR_INST", "DEM_CONT", "TIP_SIST", "ARE_LOC",
                "POINT_X", "POINT_Y"]

COLUNAS_NUMERICAS = {"CAR_INST", "DEM_CONT", "POINT_X", "POINT_Y"}

logger = logging.getLogger("etl_bdgd")


def verificar_cobertura(engine, municipios: list[str] | None, distribuidoras: list[str] | None) -> bool:
    with engine.connect() as conn:
        if distribuidoras:
            n = conn.execute(text("SELECT COUNT(*) FROM sub WHERE dist = ANY(:d)"), {"d": distribuidoras}).scalar()
            if n == 0:
                return False
        if municipios:
            existe = conn.execute(
                text("SELECT EXISTS (SELECT 1 FROM untrat WHERE mun = ANY(:m)) "
                     "OR EXISTS (SELECT 1 FROM untrmt WHERE mun = ANY(:m))"),
                {"m": municipios},
            ).scalar()
            if not existe:
                return False
    return True


def obter_csv_local(origem: str) -> Path:
    if origem.startswith(("http://", "https://")):
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        destino = CACHE_DIR / origem.rsplit("/", 1)[-1]
        if not destino.exists():
            logger.info(f"Baixando {origem}")
            temporario = destino.with_name(destino.name + ".part")
            with requests.get(origem, stream=True, timeout=60) as resposta:
                resposta.raise_for_status()
                with open(temporario, "wb") as arquivo:
                    for bloco in resposta.iter_content(1024 * 1024):
                        arquivo.write(bloco)
            temporario.rename(destino)
    else:
        destino = Path(origem)
        if not destino.exists():
            raise FileNotFoundError(f"Arquivo não encontrado: {destino}")

    return destino


def extrair_csv(origem: str, municipios: list[str] | None, distribuidoras: list[str] | None,
                colunas: list[str], tabela: str, metricas: Metricas) -> pd.DataFrame:
    caminho = obter_csv_local(origem)
    cols = sorted(set(colunas) | {"MUN", "DIST", "SIT_ATIV"})
    tipos = {c: (pa.float64() if c in COLUNAS_NUMERICAS else pa.string()) for c in cols}

    leitor = pacsv.open_csv(
        caminho,
        read_options=pacsv.ReadOptions(encoding="latin-1", block_size=BLOCK_SIZE),
        parse_options=pacsv.ParseOptions(delimiter=";"),
        convert_options=pacsv.ConvertOptions(
            include_columns=cols,
            include_missing_columns=True,
            column_types=tipos,
            strings_can_be_null=True,
        ),
    )

    partes = []
    for i, bloco in enumerate(leitor, start=1):
        ativo = pc.fill_null(pc.equal(bloco.column("SIT_ATIV"), "AT"), False)
        n_ativos = pc.sum(pc.cast(ativo, pa.int64())).as_py() or 0

        mascara = ativo
        if municipios:
            mascara = pc.and_(mascara, pc.is_in(bloco.column("MUN"), value_set=pa.array(municipios, type=pa.string())))
        if distribuidoras:
            mascara = pc.and_(mascara, pc.is_in(bloco.column("DIST"), value_set=pa.array(distribuidoras, type=pa.string())))

        filtrado = bloco.filter(mascara)
        metricas.add(tabela, lidos=bloco.num_rows, inativos=bloco.num_rows - n_ativos,
                     fora_da_selecao=n_ativos - filtrado.num_rows, retidos=filtrado.num_rows)
        if filtrado.num_rows:
            partes.append(filtrado)
        logger.info(f"  {caminho.name} bloco {i}: {filtrado.num_rows} registros retidos")

    if not partes:
        return pd.DataFrame()
    return pa.Table.from_batches(partes).to_pandas()


def _podar(df: pd.DataFrame, colunas: list[str]) -> pd.DataFrame:
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
    return df


def _pontos(x, y, index=None) -> gpd.GeoSeries:
    pontos = gpd.GeoSeries(gpd.points_from_xy(x, y), index=index, crs=CRS_ORIGEM_BDGD)
    return pontos if CRS_ORIGEM_BDGD == CRS_ALVO else pontos.to_crs(CRS_ALVO)


def _limpar_pontual(df: pd.DataFrame, colunas: list[str], tabela: str, metricas: Metricas) -> gpd.GeoDataFrame:
    df = _podar(df, colunas)
    tem_coord = df["point_x"].notna() & df["point_y"].notna()
    metricas.add(tabela, descartados_sem_coordenada=int((~tem_coord).sum()))
    df = df[tem_coord]
    geometria = _pontos(df["point_x"], df["point_y"], index=df.index)
    gdf = gpd.GeoDataFrame(df.drop(columns=["point_x", "point_y"]), geometry=geometria, crs=CRS_ALVO)
    return gdf.rename_geometry("geom")


def limpar_ucat(df, engine, tabela, metricas):
    return _limpar_pontual(df, COLUNAS_UCAT, tabela, metricas)


def limpar_ucmt(df, engine, tabela, metricas):
    return _limpar_pontual(df, COLUNAS_UCMT, tabela, metricas)


TABELAS = [
    {"tabela": "ucat_pj", "url": CSV_UCAT_PJ_URL, "colunas": COLUNAS_UCAT, "limpar": limpar_ucat,
     "fks": {"sub": ("sub", "cod_id")}},
    {"tabela": "ucmt_pj", "url": CSV_UCMT_PJ_URL, "colunas": COLUNAS_UCMT, "limpar": limpar_ucmt,
     "fks": {"sub": ("sub", "cod_id"), "uni_tr_at": ("untrat", "cod_id")}},
]


def processar_tabela(engine, cfg: dict, urls: dict, municipios, distribuidoras, metricas: Metricas,
                     prefixos: dict | None = None) -> str:
    tabela = cfg["tabela"]
    logger.info(f"Processando '{tabela}'...")

    df = extrair_csv(urls.get(tabela, cfg["url"]), municipios, distribuidoras, cfg["colunas"], tabela, metricas)
    if df.empty:
        logger.warning(f"'{tabela}': nenhum registro encontrado para a seleção — nada a carregar.")
        return tabela

    if prefixos:
        prefixo_linha = df["DIST"].map(prefixos).fillna("")
        df = prefixar(df, prefixo_linha, colunas=("COD_ID_ENCR", "SUB", "UNI_TR_AT", "UNI_TR_MT", "CTMT", "CTAT"))

    gdf = cfg["limpar"](df, engine, tabela, metricas)
    gdf = anular_fk_orfas(gdf, engine, tabela, cfg["fks"], metricas)

    with engine.begin() as conn:
        carregar_idempotente(conn, gdf, tabela, "cod_id_encr", metricas, truncar=("brr",))
    metricas.log(tabela)
    return tabela


def main(municipios: list[str] | None = None, distribuidoras: list[str] | None = None,
         urls: dict | None = None, engine=None, prefixos: dict | None = None) -> dict:
    if not municipios and not distribuidoras:
        raise ValueError("Informe ao menos um critério de busca: municipios ou distribuidoras.")
    municipios = validar_municipios(municipios) if municipios else None
    distribuidoras = [str(d) for d in distribuidoras] if distribuidoras else None

    engine = engine or create_engine(os.getenv("ETL_DB_URL"), pool_size=MAX_WORKERS + 2)
    metricas = Metricas()

    logger.info("0) Verificando cobertura no banco...")
    if not verificar_cobertura(engine, municipios, distribuidoras):
        logger.warning("Região ainda não disponível - malha elétrica não carregada para essa seleção.")
        return {"status": "indisponivel"}

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futuros = {
            executor.submit(processar_tabela, engine, cfg, urls or {}, municipios, distribuidoras, metricas, prefixos): cfg["tabela"]
            for cfg in TABELAS
        }
        for futuro in as_completed(futuros):
            futuro.result() 
            logger.info(f"'{futuros[futuro]}' finalizada.")

    logger.info("ETL concluído.")
    return {"status": "concluido", **metricas.resumo()}