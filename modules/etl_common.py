import logging
import re
import time
import uuid
from pathlib import Path

import geopandas as gpd
import pandas as pd
import requests
from shapely.geometry import MultiLineString, MultiPolygon
from sqlalchemy import text


CRS_ALVO = "EPSG:4674"
CRS_ORIGEM_BDGD = "EPSG:4674" 

logger = logging.getLogger("etl")

_REGEX_IBGE = re.compile(r"^\d{7}$")

DOWNLOAD_TENTATIVAS = 5
DOWNLOAD_TIMEOUT = (30, 60) 
DOWNLOAD_ESPERA_MAXIMA = 30
DOWNLOAD_BLOCO = 64 * 1024 
_STATUS_COM_RETRY = {408, 429}
_REGEX_CONTENT_RANGE = re.compile(r"bytes\s+(?:(\d+)-(\d+)|\*)/(\d+|\*)")


def validar_municipios(municipios) -> list[str]:
    codigos = list(dict.fromkeys(str(m).strip() for m in (municipios or []) if str(m).strip()))
    if not codigos:
        raise ValueError("Informe ao menos um código IBGE de município.")
    invalidos = [c for c in codigos if not _REGEX_IBGE.match(c)]
    if invalidos:
        raise ValueError(f"Códigos IBGE inválidos (esperado 7 dígitos): {invalidos}")
    return codigos


class _DownloadIncompleto(Exception):
    pass


def _parse_content_range(valor: str | None) -> tuple[int | None, int | None]:
    if not valor:
        return None, None
    m = _REGEX_CONTENT_RANGE.match(valor.strip())
    if not m:
        return None, None
    inicio = int(m.group(1)) if m.group(1) is not None else None
    total = int(m.group(3)) if m.group(3) != "*" else None
    return inicio, total


def baixar_com_retomada(url: str, destino: Path, tentativas: int = DOWNLOAD_TENTATIVAS) -> None:
    destino = Path(destino)
    temporario = destino.with_name(destino.name + ".part")
    ultimo_erro: Exception | None = None

    for tentativa in range(1, tentativas + 1):
        baixados = temporario.stat().st_size if temporario.exists() else 0
        headers = {"Accept-Encoding": "identity"}
        if baixados:
            headers["Range"] = f"bytes={baixados}-"
            logger.info("Retomando %s a partir de %.0f MB (tentativa %s/%s)",
                        destino.name, baixados / (1 << 20), tentativa, tentativas)

        try:
            with requests.get(url, stream=True, timeout=DOWNLOAD_TIMEOUT, headers=headers) as resposta:
                status = resposta.status_code

                if status == 416:
                    _, total = _parse_content_range(resposta.headers.get("Content-Range"))
                    if baixados and total == baixados:
                        temporario.replace(destino) 
                        return
                    temporario.unlink(missing_ok=True)
                    raise _DownloadIncompleto("Servidor recusou o Range; reiniciando o download do zero.")

                if 400 <= status < 500 and status not in _STATUS_COM_RETRY:
                    raise RuntimeError(f"Falha ao baixar {url}: HTTP {status}")
                resposta.raise_for_status()

                if status == 206:
                    inicio, total = _parse_content_range(resposta.headers.get("Content-Range"))
                    if inicio != baixados:
                        temporario.unlink(missing_ok=True)
                        raise _DownloadIncompleto(
                            f"Content-Range inesperado (início {inicio}, esperado {baixados}); reiniciando.")
                    modo = "ab"
                else:
                    if baixados:
                        logger.warning("Servidor não suporta retomada; reiniciando o download do zero.")
                    baixados = 0
                    modo = "wb"
                    comprimento = resposta.headers.get("Content-Length")
                    total = int(comprimento) if comprimento and comprimento.isdigit() else None

                with open(temporario, modo) as arquivo:
                    for bloco in resposta.iter_content(DOWNLOAD_BLOCO):
                        arquivo.write(bloco)
                        baixados += len(bloco)

            if total is not None and baixados != total:
                raise _DownloadIncompleto(f"Download incompleto: {baixados} de {total} bytes.")

            temporario.replace(destino)
            return

        except (requests.RequestException, _DownloadIncompleto) as exc:
            ultimo_erro = exc
            logger.warning("Falha ao baixar %s (tentativa %s/%s): %s: %s",
                           destino.name, tentativa, tentativas, type(exc).__name__, exc)
            if tentativa < tentativas:
                time.sleep(min(2 ** tentativa, DOWNLOAD_ESPERA_MAXIMA))

    raise RuntimeError(f"Não foi possível baixar {url} após {tentativas} tentativas: {ultimo_erro}")


class Metricas:

    def __init__(self):
        self._tabelas: dict[str, dict[str, int]] = {}

    def add(self, tabela: str, **valores) -> None:
        d = self._tabelas.setdefault(tabela, {})
        for chave, valor in valores.items():
            d[chave] = d.get(chave, 0) + int(valor)

    def log(self, tabela: str) -> None:
        d = self._tabelas.get(tabela, {})
        if not d:
            return
        logger.info("[%s] %s", tabela, " | ".join(f"{k}={v}" for k, v in d.items()))

    def resumo(self) -> dict:
        total: dict[str, int] = {}
        for d in self._tabelas.values():
            for chave, valor in d.items():
                total[chave] = total.get(chave, 0) + valor
        return {"tabelas": self._tabelas, "total": total}


_TIPOS_ACEITOS = {
    "Point": {"Point"},
    "MultiLineString": {"LineString", "MultiLineString"},
    "MultiPolygon": {"Polygon", "MultiPolygon"},
}


def normalizar_geometria(gdf, tipo_alvo: str, tabela: str, metricas: Metricas):
    if gdf.empty:
        return gdf
    antes = len(gdf)
    gdf = gdf[gdf.geometry.notna() & ~gdf.geometry.is_empty].copy()
    gdf = gdf[gdf.geom_type.isin(_TIPOS_ACEITOS[tipo_alvo])].copy()
    if gdf.empty:
        metricas.add(tabela, descartados_geometria=antes)
        return gdf

    gdf.geometry = gdf.geometry.force_2d()
    if tipo_alvo == "MultiLineString":
        gdf.geometry = gdf.geometry.apply(lambda g: MultiLineString([g]) if g.geom_type == "LineString" else g)
    elif tipo_alvo == "MultiPolygon":
        gdf.geometry = gdf.geometry.apply(lambda g: MultiPolygon([g]) if g.geom_type == "Polygon" else g)

    metricas.add(tabela, descartados_geometria=antes - len(gdf))
    return gdf


def anular_fk_orfas(df, engine, tabela: str, fks: dict, metricas: Metricas):
    for coluna, (pai, pk) in fks.items():
        if coluna not in df.columns:
            continue
        codigos = df[coluna].dropna().astype(str).unique().tolist()
        if not codigos:
            continue
        with engine.connect() as conn:
            existentes = {
                r[0]
                for r in conn.execute(text(f'SELECT "{pk}" FROM "{pai}" WHERE "{pk}" = ANY(:codigos)'), {"codigos": codigos})
            }
        orfas = df[coluna].notna() & ~df[coluna].astype(str).isin(existentes)
        n = int(orfas.sum())
        if n:
            logger.warning("[%s] %s registro(s) com %s inexistente em '%s' — FK anulada", tabela, n, coluna, pai)
            df.loc[orfas, coluna] = None
            metricas.add(tabela, **{f"fk_{coluna}_orfa_anulada": n})
    return df


def validar_tamanhos(conn, df, tabela: str, metricas: Metricas, truncar=()):
    limites = dict(conn.execute(
        text("SELECT column_name, character_maximum_length FROM information_schema.columns "
             "WHERE table_name = :t AND character_maximum_length IS NOT NULL"),
        {"t": tabela},
    ).all())
    erros = []
    copiado = False
    for coluna, limite in limites.items():
        if coluna not in df.columns:
            continue
        serie = df[coluna]
        excede = serie.notna() & (serie.astype(str).str.len() > limite)
        if not excede.any():
            continue
        if coluna in truncar:
            if not copiado:
                df, copiado = df.copy(), True
            df[coluna] = serie.where(~excede, serie.astype(str).str.slice(0, limite))
            metricas.add(tabela, **{f"{coluna}_truncados": int(excede.sum())})
        else:
            maior = serie[excede].astype(str).str.len().max()
            exemplo = str(serie[excede].astype(str).iloc[0])[:50]
            erros.append(f"'{coluna}' (limite {limite}; {int(excede.sum())} valor(es), maior {maior}; ex.: {exemplo!r})")
    if erros:
        raise ValueError(f"[{tabela}] texto maior que o limite da coluna: " + "; ".join(erros)
                         + ". Alargue a coluna ou inclua-a em `truncar`.")
    return df


def carregar_idempotente(conn, gdf, tabela: str, pk, metricas: Metricas, truncar=()) -> int:
    chaves = [pk] if isinstance(pk, str) else list(pk)
    antes = len(gdf)
    gdf = gdf[gdf[chaves].notna().all(axis=1)].drop_duplicates(subset=chaves)
    metricas.add(tabela, descartados_pk_nula_ou_repetida=antes - len(gdf))
    if gdf.empty:
        metricas.add(tabela, inseridos=0, ignorados_ja_existentes=0)
        return 0

    gdf = validar_tamanhos(conn, gdf, tabela, metricas, truncar)

    staging = f"_stg_{tabela}_{uuid.uuid4().hex[:8]}"
    alvo_conflito = ", ".join(f'"{c}"' for c in chaves)

    if isinstance(gdf, gpd.GeoDataFrame) and not gdf.geometry.notna().any():
        gdf = pd.DataFrame(gdf.drop(columns=gdf.geometry.name))
        gdf.to_sql(staging, conn, if_exists="replace", index=False)
    else:
        gdf.to_postgis(staging, conn, if_exists="replace", index=False)
    colunas = ", ".join(f'"{c}"' for c in gdf.columns)
    resultado = conn.execute(
        text(
            f'INSERT INTO "{tabela}" ({colunas}) SELECT {colunas} FROM "{staging}" '
            f'ON CONFLICT ({alvo_conflito}) DO NOTHING'
        )
    )
    inseridos = resultado.rowcount
    conn.execute(text(f'DROP TABLE "{staging}"'))

    metricas.add(tabela, inseridos=inseridos, ignorados_ja_existentes=len(gdf) - inseridos)
    return inseridos


COLUNAS_CODIGO = ("cod_id", "cod_id_encr", "sub", "uni_tr_at", "uni_tr_mt", "ctmt", "ctat")


def decidir_prefixo(conn, dist: str) -> str:
    n, com_prefixo = conn.execute(
        text("SELECT count(*), coalesce(bool_or(strpos(cod_id, ':') > 0), false) FROM sub WHERE dist = :d"),
        {"d": dist},
    ).one()
    if n > 0:
        return f"{dist}:" if com_prefixo else ""
    total = conn.execute(text("SELECT count(*) FROM sub")).scalar()
    return "" if total == 0 else f"{dist}:"


def prefixar(df, prefixo, colunas=COLUNAS_CODIGO):
    if isinstance(prefixo, str) and not prefixo:
        return df
    for c in colunas:
        if c not in df.columns:
            continue
        novo = prefixo + df[c].astype(str)
        df[c] = novo.where(df[c].notna(), None)
    return df


def vincular_baixa_tensao(conn, dist: str, prefixo: str, municipios: list[str], metricas: Metricas) -> int:
    if conn.execute(text("SELECT to_regclass('ucbt_raw') IS NOT NULL")).scalar() is not True:
        logger.warning("Tabela ucbt_raw não existe — baixa tensão não vinculada.")
        return 0

    resultado = conn.execute(
        text(
            """
            INSERT INTO ucbt (cod_id_encr, mun, brr, sub, uni_tr_at, uni_tr_mt, conj, ctmt, clas_sub,
                              cnae, car_inst, tip_sist, are_loc, geom)
            SELECT :p || r.cod_id_encr, left(r.mun, 10), left(r.brr, 60), t.sub, t.uni_tr_at, t.cod_id,
                   left(r.conj, 20), left(:p || r.ctmt, 40), left(r.clas_sub, 10), left(r.cnae, 10),
                   r.car_inst, left(r.tip_sist, 15), left(r.are_loc, 5),
                   COALESCE(r.geom, t.geom)
            FROM ucbt_raw r
            JOIN untrmt t ON t.cod_id = :p || r.uni_tr_mt
            JOIN sub s    ON s.cod_id = t.sub AND s.dist = r.dist
            WHERE r.dist = :dist AND r.mun = ANY(:municipios)
            ON CONFLICT (cod_id_encr) DO NOTHING
            """
        ),
        {"p": prefixo, "dist": dist, "municipios": municipios},
    )
    disponiveis = conn.execute(
        text("SELECT count(*) FROM ucbt_raw WHERE dist = :dist AND mun = ANY(:municipios)"),
        {"dist": dist, "municipios": municipios},
    ).scalar()
    metricas.add("ucbt", raw_disponiveis=disponiveis, inseridos=resultado.rowcount)
    metricas.add("ucbt", sem_transformador_ou_ja_existentes=disponiveis - resultado.rowcount)
    return resultado.rowcount