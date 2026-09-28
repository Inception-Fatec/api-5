import os
from pathlib import Path

import geopandas as gpd
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv

load_dotenv()

# URL do banco de dados
DB_URL = os.getenv("DB_URL")

CAMINHO_GDB_ORIGINAL = Path(os.getenv("CAMINHO_GDB_ORIGINAL"))
CAMINHO_MALHA_MUNICIPIOS = Path(os.getenv("CAMINHO_MALHA_MUNICIPIOS"))

CRS_ALVO = "EPSG:4674"

CAMADAS_PAI = [
    {
        "tabela": "sub",
        "layer_gdb": "sub",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "NOME", "DIST"],
        "referencias": ["untrat", "untrmt", "ssdat", "ssdmt", "ssdbt"]
    },
    {
        "tabela": "untrat",
        "layer_gdb": "untrat",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "SUB", "CONJ", "MUN", "ARE_LOC", "POT_NOM"],
        "referencias": ["untrmt", "ssdmt", "ssdbt"]
    },
    {
        "tabela": "untrmt",
        "layer_gdb": "untrmt",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "MUN",
                    "ARE_LOC", "POSTO", "POT_NOM", "TEN_LIN_SE"],
        "referencias": ["ssdbt"]
    },
]

CAMADAS_FOLHA = [
    {
        "tabela": "ssdat", "layer_gdb": "ssdat",
        "colunas": ["COD_ID", "SUB", "CONJ", "CTAT", "ARE_LOC", "TIP_INST"],
    },
    {
        "tabela": "ssdmt", "layer_gdb": "ssdmt",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "ARE_LOC", "TIP_INST"],
    },
    {
        "tabela": "ssdbt", "layer_gdb": "ssdbt",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "UNI_TR_MT", "CTMT", "CONJ",
                    "ARE_LOC", "TIP_INST"],
    },
]

def carregar_area_recorte(malha_path: Path, municipios: list[str]):
    malha = gpd.read_file(malha_path)
    malha = malha[malha["CD_MUN"].astype(str).isin(municipios)]

    if malha.empty:
        raise ValueError(f"Nenhum município encontrado na malha para os códigos: {municipios}")

    if str(malha.crs) != CRS_ALVO:
        malha = malha.to_crs(CRS_ALVO)

    return malha.geometry.union_all()

def recortar_camada(layer_gdb: str, colunas: list[str], area_recorte) -> gpd.GeoDataFrame:
    gdf = gpd.read_file(CAMINHO_GDB_ORIGINAL, layer=layer_gdb, mask=area_recorte)

    if str(gdf.crs) != CRS_ALVO:
        gdf = gdf.to_crs(CRS_ALVO)

    gdf = gpd.clip(gdf, area_recorte)
    presentes = [c for c in colunas if c in gdf.columns]
    gdf = gdf[presentes + ["geometry"]].copy()
    gdf.columns = [c.lower() if c != "geometry" else c for c in gdf.columns]
    return gdf.rename_geometry("geom")

def codigos_referenciados(camadas: dict, dependentes: list[str], campo: str) -> set:
    referenciados = set()
    for nome in dependentes:
        gdf = camadas[nome]
        if campo in gdf.columns:
            referenciados.update(gdf[campo].dropna().unique())
    return referenciados


def extrair_da_geodatabase_original(layer_gdb: str, campo_pk: str, colunas: list[str], codigos: list[str]) -> gpd.GeoDataFrame:
    lista_sql = ", ".join(f"'{c}'" for c in codigos)
    where = f"{campo_pk} IN ({lista_sql})"
    gdf = gpd.read_file(CAMINHO_GDB_ORIGINAL, layer=layer_gdb, where=where)

    if str(gdf.crs) != CRS_ALVO:
        gdf = gdf.to_crs(CRS_ALVO)

    presentes = [c for c in colunas if c in gdf.columns]
    gdf = gdf[presentes + ["geometry"]].copy()
    gdf.columns = [c.lower() if c != "geometry" else c for c in gdf.columns]
    return gdf.rename_geometry("geom")

def pd_concat_sem_duplicar(a: gpd.GeoDataFrame, b: gpd.GeoDataFrame, campo_pk: str) -> gpd.GeoDataFrame:
    combinado = gpd.GeoDataFrame(
        pd.concat([a, b], ignore_index=True), geometry="geom", crs=a.crs
    )
    return combinado.drop_duplicates(subset=campo_pk, keep="first")

def carregar(gdf: gpd.GeoDataFrame, tabela: str, engine) -> None:
    gdf.to_postgis(tabela, engine, if_exists="append", index=False)
    print(f"  -> {len(gdf)} registro(s) carregado(s) em '{tabela}'")

def main(municipios: list[str] = ["3549904", "3508504"]):
    engine = create_engine(DB_URL)
    area_recorte = carregar_area_recorte(CAMINHO_MALHA_MUNICIPIOS, municipios)

    camadas = {}
    for nivel in CAMADAS_PAI + CAMADAS_FOLHA:
        print(f"Recortando {nivel['tabela']} da geodatabase original...")
        camadas[nivel["tabela"]] = recortar_camada(nivel["layer_gdb"], nivel["colunas"], area_recorte)

    for nivel in CAMADAS_PAI:
        tabela = nivel["tabela"]
        campo_pk = nivel["campo_pk"].lower()
        base = camadas[tabela]

        referenciados = codigos_referenciados(camadas, nivel["referencias"], campo_pk)
        existentes = set(base[campo_pk].dropna().unique())
        faltantes = sorted(referenciados - existentes)

        if faltantes:
            print(f"{tabela}: {len(faltantes)}  código(s) fora da área recortada, buscando na geodatabase original...")
            extras = extrair_da_geodatabase_original(nivel["layer_gdb"], nivel["campo_pk"], nivel["colunas"], faltantes)
            base = pd_concat_sem_duplicar(base, extras, campo_pk)

        carregar(base, tabela, engine)

    for nivel in CAMADAS_FOLHA:
        carregar(camadas[nivel["tabela"]], nivel["tabela"], engine)

    print("\nCarga da geodatabase concluída.")


if __name__ == "__main__":
    main()