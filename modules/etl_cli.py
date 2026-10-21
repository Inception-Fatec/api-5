import argparse
import json
import logging
import sys

import etl_bdgd
import geodatabase_edp_sp


def main(argv=None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

    parser = argparse.ArgumentParser(description="ETL BDGD (geodatabase + consumidores)")
    parser.add_argument("--gdb", required=True, help="Pasta .gdb já descompactada")
    parser.add_argument("--municipios", required=True, help="Códigos IBGE separados por vírgula")
    parser.add_argument("--sem-consumidores", action="store_true",
                        help="Carrega só a geodatabase (não roda o ETL dos CSVs da ANEEL)")
    args = parser.parse_args(argv)

    municipios = [m.strip() for m in args.municipios.split(",") if m.strip()]

    try:
        resumo = {"geodatabase": geodatabase_edp_sp.main(municipios, args.gdb)}
        if not args.sem_consumidores:
            dist = resumo["geodatabase"]["distribuidora"]
            resumo["consumidores"] = etl_bdgd.main(
                municipios=municipios,
                distribuidoras=[dist],
                prefixos={dist: resumo["geodatabase"]["prefixo"]},
            )
    except Exception:
        logging.exception("ETL falhou")
        return 1

    print("ETL_RESULT:" + json.dumps(resumo, ensure_ascii=False, default=str), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())