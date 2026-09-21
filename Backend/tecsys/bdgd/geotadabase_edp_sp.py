from pathlib import Path

import geopandas as gpd
import pandas as pd
from sqlalchemy import create_engine

# URL do banco de dados
# Pasta onde este script está
BASE_DIR = Path(__file__).resolve().parent

# Banco PostgreSQL
DB_URL = "postgresql://bdgd_user:bdgd123@localhost:5432/bdgd"

# GeoPackages recortados
PASTA_RECORTES = BASE_DIR / "dados-bdgd" / "recortes"

# Procura automaticamente a geodatabase .gdb dentro de dados-bdgd
GDBS_ENCONTRADAS = list((BASE_DIR / "dados-bdgd").glob("*.gdb"))

if len(GDBS_ENCONTRADAS) != 1:
    raise RuntimeError(
        f"Esperava encontrar exatamente uma .gdb em "
        f"{BASE_DIR / 'dados-bdgd'}, mas encontrei {len(GDBS_ENCONTRADAS)}"
    )

CAMINHO_GDB_ORIGINAL = GDBS_ENCONTRADAS[0]

CRS_ALVO = "EPSG:4674"

CAMADAS_PAI = [
    {
        "tabela": "sub",
        "arquivo_local": "sub.gpkg",
        "layer_gdb": "SUB",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "NOME", "DIST"],
        "referencias": [
            ("UNTRAT.gpkg", "SUB"), ("UNTRMT.gpkg", "SUB"),
            ("SSDAT.gpkg", "SUB"), ("SSDMT.gpkg", "SUB"), ("SSDBT.gpkg", "SUB"),
        ],
    },
    {
        "tabela": "untrat",
        "arquivo_local": "UNTRAT.gpkg",
        "layer_gdb": "UNTRAT",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "SUB", "CONJ", "MUN", "ARE_LOC", "POT_NOM"],
        "referencias": [
            ("UNTRMT.gpkg", "UNI_TR_AT"), ("SSDMT.gpkg", "UNI_TR_AT"), ("SSDBT.gpkg", "UNI_TR_AT"),
        ],
    },
    {
        "tabela": "untrmt",
        "arquivo_local": "UNTRMT.gpkg",
        "layer_gdb": "UNTRMT",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "MUN",
                    "ARE_LOC", "POSTO", "POT_NOM", "TEN_LIN_SE"],
        "referencias": [
            ("SSDBT.gpkg", "UNI_TR_MT"),
        ],
    },
]

CAMADAS_FOLHA = [
    {
        "tabela": "ssdat",
        "arquivo_local": "SSDAT.gpkg",
        "colunas": ["COD_ID", "SUB", "CONJ", "CTAT", "ARE_LOC", "TIP_INST"],
    },
    {
        "tabela": "ssdmt",
        "arquivo_local": "SSDMT.gpkg",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "ARE_LOC", "TIP_INST"],
    },
    {
        "tabela": "ssdbt",
        "arquivo_local": "SSDBT.gpkg",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "UNI_TR_MT", "CTMT", "CONJ",
                    "ARE_LOC", "TIP_INST"],
    },
]

def ler_local(arquivo: str, colunas: list[str]) -> gpd.GeoDataFrame:
    gdf = gpd.read_file(PASTA_RECORTES / arquivo)

    if gdf.crs is None:
        raise ValueError(f"{arquivo}: camada sem CRS definido — confira o arquivo.")
    if str(gdf.crs) != CRS_ALVO:
        gdf = gdf.to_crs(CRS_ALVO)

    presentes = [c for c in colunas if c in gdf.columns]
    faltando = [c for c in colunas if c not in gdf.columns]
    if faltando:
        print(f"  aviso: colunas não encontradas em {arquivo}: {faltando}")

    gdf = gdf[presentes + ["geometry"]].copy()
    gdf.columns = [c.lower() if c != "geometry" else c for c in gdf.columns]
    return gdf.rename_geometry("geom")


def codigos_referenciados(referencias: list[tuple[str, str]]) -> set:
    referenciados = set()
    for arquivo, campo in referencias:
        gdf = gpd.read_file(PASTA_RECORTES / arquivo)
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

def carregar(gdf: gpd.GeoDataFrame, tabela: str, engine) -> None:
    gdf.to_postgis(tabela, engine, if_exists="append", index=False)
    print(f"  -> {len(gdf)} registro(s) carregado(s) em '{tabela}'")


def carregar_camada_pai(camada: dict, engine) -> None:
    tabela = camada["tabela"]
    campo_pk = camada["campo_pk"].lower()
    print(f"\nCarregando {tabela} a partir de {camada['arquivo_local']}...")

    base = ler_local(camada["arquivo_local"], camada["colunas"])

    referenciados = codigos_referenciados(camada["referencias"])
    existentes = set(base[campo_pk].dropna().unique())
    faltantes = sorted(referenciados - existentes)

    if faltantes:
        print(f"  {len(faltantes)} código(s) referenciado(s) fora do recorte: {faltantes}")
        print("  buscando na geodatabase original...")
        extras = extrair_da_geodatabase_original(
            camada["layer_gdb"], camada["campo_pk"], camada["colunas"], faltantes
        )
        encontrados = set(extras[campo_pk])
        nao_encontrados = set(faltantes) - encontrados
        if nao_encontrados:
            print(f"  aviso: não encontrados nem na geodatabase original: {sorted(nao_encontrados)}")

        base = pd_concat_sem_duplicar(base, extras, campo_pk)

    carregar(base, tabela, engine)


def pd_concat_sem_duplicar(a: gpd.GeoDataFrame, b: gpd.GeoDataFrame, campo_pk: str) -> gpd.GeoDataFrame:
    combinado = gpd.GeoDataFrame(
        pd.concat([a, b], ignore_index=True), geometry="geom", crs=a.crs
    )
    return combinado.drop_duplicates(subset=campo_pk, keep="first")


def carregar_camada_folha(camada: dict, engine) -> None:
    print(f"\nCarregando {camada['tabela']} a partir de {camada['arquivo_local']}...")
    gdf = ler_local(camada["arquivo_local"], camada["colunas"])
    carregar(gdf, camada["tabela"], engine)

def main():
    engine = create_engine(DB_URL)

    for camada in CAMADAS_PAI:
        carregar_camada_pai(camada, engine)

    for camada in CAMADAS_FOLHA:
        carregar_camada_folha(camada, engine)

    print("\nCarga da geodatabase EDP_SP concluída.")


if __name__ == "__main__":
    main()