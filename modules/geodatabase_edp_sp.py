import logging
import os
import time
from pathlib import Path

import geopandas as gpd
import pandas as pd
import pyogrio
import requests
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

from etl_common import (
    CRS_ALVO,
    Metricas,
    carregar_idempotente,
    decidir_prefixo,
    normalizar_geometria,
    prefixar,
    validar_municipios,
    vincular_baixa_tensao,
)

load_dotenv()
logger = logging.getLogger("etl.gdb")

IBGE_MALHAS_URL = os.getenv("IBGE_MALHAS_URL", "https://servicodados.ibge.gov.br/api/v4/malhas/municipios")
CRS_MALHA_IBGE = "EPSG:4674"

CAMADAS_PAI = [
    {
        "tabela": "sub", "layer_gdb": "sub", "campo_pk": "COD_ID", "geom_tipo": "MultiPolygon",
        "colunas": ["COD_ID", "NOME", "DIST"],
        "fk_nos_filhos": "sub",
        "referencias": ["untrat", "untrmt", "ssdat", "ssdmt", "ssdbt"],
    },
    {
        "tabela": "untrat", "layer_gdb": "untrat", "campo_pk": "COD_ID", "geom_tipo": "Point",
        "colunas": ["COD_ID", "SUB", "CONJ", "MUN", "ARE_LOC", "POT_NOM"],
        "fk_nos_filhos": "uni_tr_at",
        "referencias": ["untrmt", "ssdmt", "ssdbt"],
    },
    {
        "tabela": "untrmt", "layer_gdb": "untrmt", "campo_pk": "COD_ID", "geom_tipo": "Point",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "MUN",
                    "ARE_LOC", "POSTO", "POT_NOM", "TEN_LIN_SE"],
        "fk_nos_filhos": "uni_tr_mt",
        "referencias": ["ssdbt"],
    },
]

CAMADAS_FOLHA = [
    {
        "tabela": "ssdat", "layer_gdb": "ssdat", "campo_pk": "COD_ID", "geom_tipo": "MultiLineString",
        "colunas": ["COD_ID", "SUB", "CONJ", "CTAT", "ARE_LOC", "TIP_INST"],
    },
    {
        "tabela": "ssdmt", "layer_gdb": "ssdmt", "campo_pk": "COD_ID", "geom_tipo": "MultiLineString",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "ARE_LOC", "TIP_INST"],
    },
    {
        "tabela": "ssdbt", "layer_gdb": "ssdbt", "campo_pk": "COD_ID", "geom_tipo": "MultiLineString",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "UNI_TR_MT", "CTMT", "CONJ",
                    "ARE_LOC", "TIP_INST"],
    },
]


class MunicipioNaoEncontrado(ValueError):
    pass


def _baixar_malha_municipio(codigo: str, tentativas: int = 3) -> dict:
    ultimo_erro = None
    for tentativa in range(1, tentativas + 1):
        try:
            resposta = requests.get(
                f"{IBGE_MALHAS_URL}/{codigo}",
                params={"formato": "application/vnd.geo+json", "qualidade": "maxima"},
                timeout=60,
            )
            if resposta.status_code in (400, 404):
                raise MunicipioNaoEncontrado(f"Município {codigo} não encontrado na API de malhas do IBGE.")
            resposta.raise_for_status()
            return resposta.json()
        except MunicipioNaoEncontrado:
            raise
        except (requests.RequestException, ValueError) as exc:
            ultimo_erro = exc
            logger.warning("Falha ao consultar a malha do município %s (tentativa %s/%s): %s",
                           codigo, tentativa, tentativas, exc)
            time.sleep(2 * tentativa)
    raise RuntimeError(f"Não foi possível consultar a API de malhas do IBGE para {codigo}: {ultimo_erro}")


def carregar_area_recorte(municipios: list[str]):
    geometrias = []
    for codigo in municipios:
        dados = _baixar_malha_municipio(codigo)
        features = dados["features"] if dados.get("type") == "FeatureCollection" else [dados]
        gdf = gpd.GeoDataFrame.from_features(features, crs=CRS_MALHA_IBGE)
        if gdf.empty:
            raise MunicipioNaoEncontrado(f"A API do IBGE não devolveu geometria para o município {codigo}.")
        geometrias.extend(gdf.geometry)
        logger.info("Malha do município %s obtida do IBGE.", codigo)

    area = gpd.GeoSeries(geometrias, crs=CRS_MALHA_IBGE)
    if area.crs != CRS_ALVO:
        area = area.to_crs(CRS_ALVO)
    return area.union_all()


def _mascara_no_crs_da_camada(gdb: Path, layer: str, area):
    crs_camada = pyogrio.read_info(gdb, layer=layer).get("crs")
    if not crs_camada:
        return area
    return gpd.GeoSeries([area], crs=CRS_ALVO).to_crs(crs_camada).iloc[0]


def _para_crs_alvo(gdf: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
    if gdf.crs is not None and gdf.crs != CRS_ALVO:
        gdf = gdf.to_crs(CRS_ALVO)
    return gdf


def _podar_colunas(gdf: gpd.GeoDataFrame, colunas: list[str]) -> gpd.GeoDataFrame:
    presentes = [c for c in colunas if c in gdf.columns]
    gdf = gdf[presentes + ["geometry"]].copy()
    gdf.columns = [c.lower() if c != "geometry" else c for c in gdf.columns]
    return gdf.rename_geometry("geom")


def recortar_camada(gdb: Path, nivel: dict, area, metricas: Metricas) -> gpd.GeoDataFrame:
    tabela = nivel["tabela"]
    mascara = _mascara_no_crs_da_camada(gdb, nivel["layer_gdb"], area)
    gdf = _para_crs_alvo(gpd.read_file(gdb, layer=nivel["layer_gdb"], mask=mascara))
    metricas.add(tabela, lidos=len(gdf))

    dentro = gdf.intersects(area)
    metricas.add(tabela, fora_municipio=int((~dentro).sum()))
    gdf = gdf[dentro]

    if "SIT_ATIV" in gdf.columns:
        ativos = gdf["SIT_ATIV"] == "AT"
        metricas.add(tabela, inativos=int((~ativos).sum()))
        gdf = gdf[ativos]

    gdf = normalizar_geometria(gdf, nivel["geom_tipo"], tabela, metricas)
    return _podar_colunas(gdf, nivel["colunas"])


def codigos_referenciados(camadas: dict, dependentes: list[str], campo: str) -> set:
    referenciados = set()
    for nome in dependentes:
        gdf = camadas[nome]
        if campo in gdf.columns:
            referenciados.update(gdf[campo].dropna().unique())
    return referenciados


def extrair_da_geodatabase_original(gdb: Path, nivel: dict, codigos, metricas: Metricas,
                                   tamanho_lote: int = 500) -> gpd.GeoDataFrame:
    partes = []
    codigos = list(codigos)
    campo_pk = nivel["campo_pk"]
    for i in range(0, len(codigos), tamanho_lote):
        lote = codigos[i:i + tamanho_lote]
        lista_sql = ", ".join("'" + str(c).replace("'", "''") + "'" for c in lote)
        partes.append(gpd.read_file(gdb, layer=nivel["layer_gdb"], where=f"{campo_pk} IN ({lista_sql})"))

    gdf = _para_crs_alvo(gpd.GeoDataFrame(pd.concat(partes, ignore_index=True), crs=partes[0].crs))
    gdf = normalizar_geometria(gdf, nivel["geom_tipo"], nivel["tabela"], metricas)
    return _podar_colunas(gdf, nivel["colunas"])


def pd_concat_sem_duplicar(a: gpd.GeoDataFrame, b: gpd.GeoDataFrame, campo_pk: str) -> gpd.GeoDataFrame:
    combinado = gpd.GeoDataFrame(pd.concat([a, b], ignore_index=True), geometry="geom", crs=a.crs)
    return combinado.drop_duplicates(subset=campo_pk, keep="first")


def descobrir_distribuidora(gdb: Path) -> str:
    valores = pyogrio.read_dataframe(gdb, layer="sub", columns=["DIST"], read_geometry=False)["DIST"]
    distintos = sorted({str(v).strip() for v in valores.dropna() if str(v).strip()})
    if len(distintos) != 1:
        raise ValueError(f"A geodatabase deveria ter exatamente 1 distribuidora na camada sub, achei: {distintos}")
    return distintos[0]


def garantir_integridade(camadas: dict, metricas: Metricas) -> None:
    for nivel in CAMADAS_PAI:
        pk = nivel["campo_pk"].lower()
        coluna = nivel["fk_nos_filhos"]
        existentes = set(camadas[nivel["tabela"]][pk].dropna().unique())
        for nome in nivel["referencias"]:
            filho = camadas[nome]
            if coluna not in filho.columns:
                continue
            orfas = filho[coluna].notna() & ~filho[coluna].isin(existentes)
            n = int(orfas.sum())
            if n:
                codigos_orfaos = filho.loc[orfas, coluna].value_counts()
                amostra = ", ".join(f"{c} ({q})" for c, q in codigos_orfaos.head(5).items())
                logger.warning("[%s] %s registro(s) com %s sem pai em '%s' (%s código(s) distintos; mais frequentes: %s) — FK anulada",
                               nome, n, coluna, nivel["tabela"], len(codigos_orfaos), amostra)
                filho.loc[orfas, coluna] = None
                metricas.add(nome, **{f"fk_{coluna}_orfa_anulada": n})


def main(municipios: list[str], caminho_gdb, engine=None) -> dict:
    municipios = validar_municipios(municipios)

    caminho_gdb = Path(caminho_gdb)
    if not caminho_gdb.is_dir() or caminho_gdb.suffix.lower() != ".gdb":
        raise ValueError(f"Geodatabase inválida (esperada uma pasta .gdb): {caminho_gdb}")

    engine = engine or create_engine(os.getenv("ETL_DB_URL"))
    metricas = Metricas()
    dist = descobrir_distribuidora(caminho_gdb)
    logger.info("Distribuidora do .gdb: %s", dist)
    area = carregar_area_recorte(municipios)

    camadas = {}
    for nivel in CAMADAS_PAI + CAMADAS_FOLHA:
        logger.info("Lendo %s da geodatabase...", nivel["tabela"])
        camadas[nivel["tabela"]] = recortar_camada(caminho_gdb, nivel, area, metricas)

    for nivel in reversed(CAMADAS_PAI):
        tabela = nivel["tabela"]
        pk = nivel["campo_pk"].lower()
        base = camadas[tabela]

        referenciados = codigos_referenciados(camadas, nivel["referencias"], nivel["fk_nos_filhos"])
        faltantes = sorted(referenciados - set(base[pk].dropna().unique()))
        if faltantes:
            logger.info("%s: %s código(s) fora da área, buscando na geodatabase original...", tabela, len(faltantes))
            extras = extrair_da_geodatabase_original(caminho_gdb, nivel, faltantes, metricas)
            metricas.add(tabela, pais_fora_da_area=len(extras))
            base = pd_concat_sem_duplicar(base, extras, pk)
        camadas[tabela] = base

    garantir_integridade(camadas, metricas)

    with engine.begin() as conn:
        prefixo = decidir_prefixo(conn, dist)
        logger.info("Distribuidora %s: prefixo de códigos = %r", dist, prefixo)
        for nivel in CAMADAS_PAI + CAMADAS_FOLHA:
            prefixar(camadas[nivel["tabela"]], prefixo)

        codigos_sub = camadas["sub"]["cod_id"].dropna().tolist()
        conflito = conn.execute(
            text("SELECT count(*) FROM sub WHERE cod_id = ANY(:c) AND dist <> :d"),
            {"c": codigos_sub, "d": dist},
        ).scalar()
        if conflito:
            raise ValueError(f"{conflito} COD_ID de subestação já pertencem a outra distribuidora no banco.")

        for nivel in CAMADAS_PAI + CAMADAS_FOLHA:
            tabela = nivel["tabela"]
            carregar_idempotente(
                conn, 
                camadas[tabela], 
                tabela, 
                nivel["campo_pk"].lower(), 
                metricas, 
                truncar=("nome", "dist", "mun", "are_loc", "posto", "tip_inst", "ctat", "ctmt")
            )
            metricas.log(tabela)

        vincular_baixa_tensao(conn, dist, prefixo, municipios, metricas)
        metricas.log("ucbt")

    logger.info("Carga da geodatabase concluída.")
    return {"status": "concluido", "distribuidora": dist, "prefixo": prefixo, **metricas.resumo()}