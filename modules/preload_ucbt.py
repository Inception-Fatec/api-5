"""Pré-carga da baixa tensão (UCBT) da ANEEL na tabela `ucbt_raw`.

Rode UMA vez (ou quando a ANEEL publicar uma versão nova). É lento de propósito: baixa o CSV nacional,
filtra só os ativos e grava em blocos. Não depende de nenhum .gdb e não toca nas outras tabelas.
O vínculo com os transformadores acontece depois, no upload de cada .gdb (etl_common.vincular_baixa_tensao).

Uso:
    python preload_ucbt.py                          # baixa o zip da ANEEL (URL padrão)
    python preload_ucbt.py --arquivo ucbt_pj.zip    # arquivo .zip ou .csv local
    python preload_ucbt.py --distribuidoras 391     # opcional: só estas distribuidoras
"""
import argparse
import logging
import os
import shutil
import sys
import zipfile
from pathlib import Path

import geopandas as gpd
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.csv as pacsv
import requests
from dotenv import load_dotenv
from sqlalchemy import create_engine

from etl_common import CRS_ALVO, CRS_ORIGEM_BDGD, Metricas, carregar_idempotente

load_dotenv()
logger = logging.getLogger("preload_ucbt")

CSV_UCBT_PJ_URL = "https://dadosabertos.aneel.gov.br/dataset/4459e483-451f-4444-8022-bd8b5eac05c5/resource/3ae4d382-7072-4b08-90a4-dcd187a2eae2/download/ucbt_pj.zip"
CACHE_DIR = Path(os.getenv("CACHE_DIR", "cache_aneel"))
BLOCK_SIZE = 64 << 20

COLUNAS = ["DIST", "COD_ID_ENCR", "MUN", "BRR", "SUB", "UNI_TR_AT", "UNI_TR_MT", "CONJ", "CTMT",
           "CLAS_SUB", "CNAE", "CAR_INST", "TIP_SIST", "ARE_LOC", "POINT_X", "POINT_Y", "SIT_ATIV"]
NUMERICAS = {"CAR_INST", "POINT_X", "POINT_Y"}


def obter_csv_local(origem: str) -> Path:
    """URL (baixa para o cache) ou caminho local; descompacta .zip se preciso."""
    if origem.startswith(("http://", "https://")):
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        destino = CACHE_DIR / origem.rsplit("/", 1)[-1]
        if not destino.exists():
            logger.info("Baixando %s", origem)
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

    if destino.suffix.lower() != ".zip":
        return destino

    csv_local = destino.with_suffix(".csv")
    if not csv_local.exists():
        logger.info("Descompactando %s", destino.name)
        temporario = csv_local.with_name(csv_local.name + ".part")
        with zipfile.ZipFile(destino) as pacote:
            nome = next(n for n in pacote.namelist() if n.lower().endswith(".csv"))
            with pacote.open(nome) as origem_zip, open(temporario, "wb") as saida:
                shutil.copyfileobj(origem_zip, saida, 1024 * 1024)
        temporario.rename(csv_local)
    return csv_local


def _bloco_para_gdf(bloco: pa.Table, metricas: Metricas) -> gpd.GeoDataFrame:
    df = bloco.to_pandas()
    sem_dist = df["DIST"].isna()
    metricas.add("ucbt_raw", descartados_sem_dist=int(sem_dist.sum()))
    df = df[~sem_dist].drop(columns=["SIT_ATIV"])
    df.columns = df.columns.str.lower()

    tem_coord = df["point_x"].notna() & df["point_y"].notna()
    geom = gpd.GeoSeries([None] * len(df), index=df.index, crs=CRS_ORIGEM_BDGD)
    if tem_coord.any():
        pontos = gpd.GeoSeries(gpd.points_from_xy(df.loc[tem_coord, "point_x"], df.loc[tem_coord, "point_y"]),
                               index=df.index[tem_coord], crs=CRS_ORIGEM_BDGD)
        geom.loc[tem_coord] = pontos
    if CRS_ORIGEM_BDGD != CRS_ALVO:
        geom = geom.to_crs(CRS_ALVO)

    gdf = gpd.GeoDataFrame(df.drop(columns=["point_x", "point_y"]), geometry=geom, crs=CRS_ALVO)
    return gdf.rename_geometry("geom")


def main(origem: str = CSV_UCBT_PJ_URL, distribuidoras: list[str] | None = None, engine=None) -> dict:
    engine = engine or create_engine(os.getenv("ETL_DB_URL"))
    metricas = Metricas()
    caminho = obter_csv_local(origem)

    tipos = {c: (pa.float64() if c in NUMERICAS else pa.string()) for c in COLUNAS}
    leitor = pacsv.open_csv(
        caminho,
        read_options=pacsv.ReadOptions(encoding="latin-1", block_size=BLOCK_SIZE),
        parse_options=pacsv.ParseOptions(delimiter=";"),
        convert_options=pacsv.ConvertOptions(include_columns=COLUNAS, include_missing_columns=True,
                                             column_types=tipos, strings_can_be_null=True),
    )

    for i, bloco in enumerate(leitor, start=1):
        ativo = pc.fill_null(pc.equal(bloco.column("SIT_ATIV"), "AT"), False)
        mascara = ativo
        if distribuidoras:
            mascara = pc.and_(mascara, pc.is_in(bloco.column("DIST"), value_set=pa.array(distribuidoras, type=pa.string())))
        filtrado = bloco.filter(mascara)
        metricas.add("ucbt_raw", lidos=bloco.num_rows,
                     inativos=bloco.num_rows - (pc.sum(pc.cast(ativo, pa.int64())).as_py() or 0))
        if not filtrado.num_rows:
            continue

        gdf = _bloco_para_gdf(filtrado, metricas)
        with engine.begin() as conn:  # um commit por bloco: a pré-carga pode ser retomada
            carregar_idempotente(conn, gdf, "ucbt_raw", ["dist", "cod_id_encr"], metricas)
        logger.info("bloco %s: %s registros ativos processados", i, filtrado.num_rows)

    metricas.log("ucbt_raw")
    return {"status": "concluido", **metricas.resumo()}


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    parser = argparse.ArgumentParser(description="Pré-carga da baixa tensão em ucbt_raw")
    parser.add_argument("--arquivo", default=CSV_UCBT_PJ_URL, help="URL ou caminho do .zip/.csv da UCBT")
    parser.add_argument("--distribuidoras", help="Códigos DIST separados por vírgula (opcional)")
    args = parser.parse_args()
    dists = [d.strip() for d in args.distribuidoras.split(",")] if args.distribuidoras else None
    resultado = main(args.arquivo, dists)
    print(resultado["total"])
    sys.exit(0)