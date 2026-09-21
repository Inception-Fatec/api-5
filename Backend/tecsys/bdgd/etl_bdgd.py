from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import Point
from sqlalchemy import create_engine

BASE_DIR = Path(__file__).resolve().parent

DB_URL = "postgresql://bdgd_user:bdgd123@localhost:5432/bdgd"

MUNICIPIOS = ["3549904", "3508504"]  # São José dos Campos, Caçapava

CSV_UCAT_PJ_URL = (
    "https://dadosabertos.aneel.gov.br/"
    "dataset/4459e483-451f-4444-8022-bd8b5eac05c5/"
    "resource/4318d38a-0bcd-421d-afb1-fb88b0c92a87/"
    "download/ucat_pj.csv"
)

CSV_UCMT_PJ_URL = (
    "https://dadosabertos.aneel.gov.br/"
    "dataset/4459e483-451f-4444-8022-bd8b5eac05c5/"
    "resource/f6671cba-f269-42ef-8eb3-62cb3bfa0b98/"
    "download/ucmt_pj.csv"
)

# Caminho para o zip dos dados de baixa tensão
# Pegar zip UCBT_PJ.zip do site da Aneel: https://dadosabertos.aneel.gov.br/dataset/base-de-dados-geografica-da-distribuidora-bdgd
# Não é necessario descompactar
CAMINHO_UCBT_ZIP = BASE_DIR / "dados-bdgd" / "UCBT_PJ.zip"

# Caminho da geodatabase COMPLETA original — usada só se algum consumidor referenciar um sub/untrat/untrmt que ainda não está no banco
GDBS_ENCONTRADAS = list((BASE_DIR / "dados-bdgd").glob("*.gdb"))

if len(GDBS_ENCONTRADAS) != 1:
    raise RuntimeError(
        f"Esperava encontrar exatamente uma .gdb em "
        f"{BASE_DIR / 'dados-bdgd'}, mas encontrei {len(GDBS_ENCONTRADAS)}"
    )

CAMINHO_GDB_ORIGINAL = GDBS_ENCONTRADAS[0]

CRS_ALVO = "EPSG:4674"

PAIS = {
    "sub": {
        "layer_gdb": "sub",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "NOME", "DIST"],
    },
    "untrat": {
        "layer_gdb": "UNTRAT",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "SUB", "CONJ", "MUN", "ARE_LOC", "POT_NOM"],
    },
    "untrmt": {
        "layer_gdb": "UNTRMT",
        "campo_pk": "COD_ID",
        "colunas": ["COD_ID", "SUB", "UNI_TR_AT", "CTMT", "CONJ", "MUN",
                    "ARE_LOC", "POSTO", "POT_NOM", "TEN_LIN_SE"],
    },
}

CHUNK_SIZE = 200_000

def extrair_csv(fonte, chunksize: int = CHUNK_SIZE) -> pd.DataFrame:
    partes = []
    leitor = pd.read_csv(fonte, sep=";", encoding="latin-1", chunksize=chunksize)
    for i, pedaco in enumerate(leitor, start=1):
        pedaco = pedaco[pedaco["MUN"].astype(str).isin(MUNICIPIOS)]
        pedaco = pedaco[pedaco["SIT_ATIV"] == "AT"]
        if not pedaco.empty:
            partes.append(pedaco)
        print(f"  chunk {i}: {len(pedaco)} registros retidos")

    return pd.concat(partes, ignore_index=True) if partes else pd.DataFrame()


def extrair_ucbt_zip(caminho: Path, chunksize: int = CHUNK_SIZE) -> pd.DataFrame:
    import zipfile

    zf = zipfile.ZipFile(caminho)
    nome_csv = next(n for n in zf.namelist() if n.lower().endswith(".csv"))
    with zf.open(nome_csv) as fonte:
        df = extrair_csv(fonte, chunksize)
    zf.close()
    return df

def para_geodataframe(df: pd.DataFrame) -> gpd.GeoDataFrame:
    geometry = [Point(xy) for xy in zip(df["point_x"], df["point_y"])]
    gdf = gpd.GeoDataFrame(df, geometry=geometry, crs=CRS_ALVO)
    gdf = gdf.drop(columns=["point_x", "point_y"])
    return gdf.rename_geometry("geom")


def limpar_ucat(df: pd.DataFrame) -> gpd.GeoDataFrame:
    colunas = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "CONJ", "CTAT", "CLAS_SUB",
               "CNAE", "CAR_INST", "DEM_CONT", "TIP_SIST", "ARE_LOC",
               "POINT_X", "POINT_Y"]
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
    return para_geodataframe(df)


def limpar_ucmt(df: pd.DataFrame) -> gpd.GeoDataFrame:
    colunas = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "UNI_TR_AT", "CONJ", "CTMT",
               "CLAS_SUB", "CNAE", "CAR_INST", "DEM_CONT", "TIP_SIST", "ARE_LOC",
               "POINT_X", "POINT_Y"]
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
    return para_geodataframe(df)


def limpar_ucbt(df: pd.DataFrame) -> gpd.GeoDataFrame:
    colunas = ["COD_ID_ENCR", "MUN", "BRR", "SUB", "UNI_TR_AT", "UNI_TR_MT",
               "CONJ", "CTMT", "CLAS_SUB", "CNAE", "CAR_INST", "TIP_SIST",
               "ARE_LOC", "POINT_X", "POINT_Y"]
    df = df[[c for c in colunas if c in df.columns]].copy()
    df.columns = df.columns.str.lower()
    return para_geodataframe(df)

def codigos_existentes_no_banco(tabela: str, engine) -> set:
    df = pd.read_sql(f"SELECT DISTINCT cod_id FROM {tabela}", engine)
    return set(df["cod_id"].dropna())


def garantir_referencias(gdf: gpd.GeoDataFrame, campo_fk: str, tabela_pai: str, engine) -> None:

    if campo_fk not in gdf.columns:
        return

    referenciados = set(gdf[campo_fk].dropna().unique())
    existentes = codigos_existentes_no_banco(tabela_pai, engine)
    faltantes = sorted(referenciados - existentes)
    if not faltantes:
        return

    print(f"  completando '{tabela_pai}': {len(faltantes)} código(s) referenciado(s) por "
          f"consumidores mas ausente(s) no banco: {faltantes}")

    info = PAIS[tabela_pai]
    lista_sql = ", ".join(f"'{c}'" for c in faltantes)
    where = f"{info['campo_pk']} IN ({lista_sql})"
    extra = gpd.read_file(CAMINHO_GDB_ORIGINAL, layer=info["layer_gdb"], where=where)

    if str(extra.crs) != CRS_ALVO:
        extra = extra.to_crs(CRS_ALVO)

    presentes = [c for c in info["colunas"] if c in extra.columns]
    extra = extra[presentes + ["geometry"]].copy()
    extra.columns = [c.lower() if c != "geometry" else c for c in extra.columns]
    extra = extra.rename_geometry("geom")

    encontrados = set(extra["cod_id"])
    nao_encontrados = set(faltantes) - encontrados
    if nao_encontrados:
        print(f"    aviso: não encontrados nem na geodatabase original: {sorted(nao_encontrados)}")

    if len(extra):
        extra.to_postgis(tabela_pai, engine, if_exists="append", index=False)
        print(f"    -> {len(extra)} registro(s) adicionado(s) em '{tabela_pai}'")

def carregar(gdf: gpd.GeoDataFrame, tabela: str, engine) -> None:
    """Carrega o GeoDataFrame na tabela já existente no banco (ver DDL)."""
    gdf.to_postgis(tabela, engine, if_exists="append", index=False)
    print(f"  -> {len(gdf)} registros carregados em '{tabela}'")

def main():
    engine = create_engine(DB_URL)

    print("1) Baixando e filtrando UCAT_PJ...")
    df_at = extrair_csv(CSV_UCAT_PJ_URL)
    gdf_at = limpar_ucat(df_at)
    garantir_referencias(gdf_at, "sub", "sub", engine)
    carregar(gdf_at, "ucat_pj", engine)
 
    print("2) Baixando e filtrando UCMT_PJ...")
    df_mt = extrair_csv(CSV_UCMT_PJ_URL)
    gdf_mt = limpar_ucmt(df_mt)
    garantir_referencias(gdf_mt, "sub", "sub", engine)
    garantir_referencias(gdf_mt, "uni_tr_at", "untrat", engine)
    carregar(gdf_mt, "ucmt_pj", engine)

    print("3) Lendo UCBT a partir do zip local...")
    df_bt = extrair_ucbt_zip(CAMINHO_UCBT_ZIP)
    gdf_bt = limpar_ucbt(df_bt)
    garantir_referencias(gdf_bt, "sub", "sub", engine)
    garantir_referencias(gdf_bt, "uni_tr_at", "untrat", engine)
    garantir_referencias(gdf_bt, "uni_tr_mt", "untrmt", engine)
    carregar(gdf_bt, "ucbt", engine)

    print("ETL concluído.")

if __name__ == "__main__":
    main()