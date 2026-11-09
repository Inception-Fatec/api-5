"""Inspeção rápida de uma geodatabase antes da carga (#TG-143).

Descobre a distribuidora, o período dos dados e quais municípios existem no
arquivo (campo MUN dos transformadores de média tensão), com a quantidade de
transformadores e de consumidores de baixa tensão de cada um. Lê só colunas
de atributos, sem geometria, então leva segundos mesmo no arquivo inteiro.
"""
import logging
import re
from collections import Counter

import pyogrio

from etl_common import resolver_gdb
from geodatabase_edp_sp import descobrir_distribuidora

logger = logging.getLogger("etl.inspecao")

_REGEX_IBGE = re.compile(r"^\d{7}$")


def _contar_municipios(gdb, layer: str) -> Counter:
    try:
        valores = pyogrio.read_dataframe(gdb, layer=layer, columns=["MUN"], read_geometry=False)["MUN"]
    except Exception as e:  # camada ausente ou sem MUN: não impede a inspeção
        logger.warning("Não foi possível ler MUN de %s: %s", layer, e)
        return Counter()
    return Counter(str(v).strip() for v in valores.dropna() if _REGEX_IBGE.match(str(v).strip()))


def _periodo(gdb) -> dict | None:
    try:
        base = pyogrio.read_dataframe(gdb, layer="BASE", columns=["DAT_INC", "DAT_FNL"], read_geometry=False)
    except Exception:
        return None
    if base.empty:
        return None
    linha = base.iloc[0]
    return {"inicio": str(linha["DAT_INC"] or "").strip(), "fim": str(linha["DAT_FNL"] or "").strip()}


def inspecionar(caminho) -> dict:
    """Aceita a pasta .gdb ou o .zip que a contém (lido sem descompactar)."""
    gdb = resolver_gdb(caminho)

    dist = descobrir_distribuidora(gdb)
    transformadores = _contar_municipios(gdb, "UNTRMT")
    if not transformadores:
        raise ValueError("A geodatabase não tem transformadores de média tensão (UNTRMT) com município.")
    consumidores_bt = _contar_municipios(gdb, "UCBT_tab")

    municipios = [
        {"codigo": codigo, "transformadores": n, "consumidores_bt": consumidores_bt.get(codigo, 0)}
        for codigo, n in sorted(transformadores.items())
    ]
    logger.info("Distribuidora %s: %s município(s) na geodatabase.", dist, len(municipios))
    return {"distribuidora": dist, "periodo": _periodo(gdb), "municipios": municipios}
