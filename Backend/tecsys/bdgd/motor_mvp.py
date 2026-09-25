import psycopg2


DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "bdgd",
    "user": "bdgd_user",
    "password": "bdgd123",
}


# Região que estamos usando no primeiro teste
CENTRO_LONGITUDE = -45.90906541157879
CENTRO_LATITUDE = -23.217235515848046

# Região escolhida pelo usuário no MVP
RAIO_REGIAO_M = 3_000

# Alcance nominal informado pela Tecsys
ALCANCE_GATEWAY_M = 1_000


def criar_regiao_teste(cursor):
    """
    Cria tabelas temporárias contendo SOMENTE
    pontos e candidatos dentro da região definida.
    """

    print("\nPreparando região de análise...")

    cursor.execute(
        """
        CREATE TEMP TABLE pontos_regiao AS
        SELECT
            nivel,
            id,
            mun,
            brr,
            geom
        FROM vw_pontos_cobertura
        WHERE ST_DWithin(
            geom::geography,
            ST_SetSRID(
                ST_MakePoint(%s, %s),
                4674
            )::geography,
            %s
        );
        """,
        (
            CENTRO_LONGITUDE,
            CENTRO_LATITUDE,
            RAIO_REGIAO_M,
        ),
    )

    cursor.execute(
        """
        CREATE TEMP TABLE candidatos_regiao AS
        SELECT
            tipo,
            id,
            posto,
            sub,
            geom
        FROM vw_candidatos_gateway
        WHERE ST_DWithin(
            geom::geography,
            ST_SetSRID(
                ST_MakePoint(%s, %s),
                4674
            )::geography,
            %s
        );
        """,
        (
            CENTRO_LONGITUDE,
            CENTRO_LATITUDE,
            RAIO_REGIAO_M,
        ),
    )

    # Índices espaciais para acelerar os ST_DWithin
    cursor.execute(
        """
        CREATE INDEX idx_tmp_pontos_geom
        ON pontos_regiao
        USING GIST (geom);
        """
    )

    cursor.execute(
        """
        CREATE INDEX idx_tmp_candidatos_geom
        ON candidatos_regiao
        USING GIST (geom);
        """
    )

    cursor.execute("ANALYZE pontos_regiao;")
    cursor.execute("ANALYZE candidatos_regiao;")


def criar_pontos_nao_cobertos(cursor):
    """
    No início todos os pontos da região estão descobertos.
    """

    cursor.execute(
        """
        CREATE TEMP TABLE pontos_nao_cobertos AS
        SELECT *
        FROM pontos_regiao;
        """
    )

    cursor.execute(
        """
        CREATE INDEX idx_tmp_nao_cobertos_geom
        ON pontos_nao_cobertos
        USING GIST (geom);
        """
    )

    cursor.execute("ANALYZE pontos_nao_cobertos;")


def contar_dados(cursor):
    cursor.execute("SELECT COUNT(*) FROM pontos_regiao;")
    total_pontos = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM candidatos_regiao;")
    total_candidatos = cursor.fetchone()[0]

    return total_pontos, total_candidatos


def buscar_melhor_gateway(cursor, gateways_usados):
    """
    Procura o candidato que cobre a maior quantidade
    de pontos que AINDA NÃO foram cobertos.
    """

    parametros = [ALCANCE_GATEWAY_M]

    filtro_usados = ""

    if gateways_usados:
        placeholders = ",".join(["(%s, %s)"] * len(gateways_usados))

        filtro_usados = f"""
            AND (c.tipo, c.id) NOT IN ({placeholders})
        """

        for tipo, gateway_id in gateways_usados:
            parametros.extend([tipo, gateway_id])

    query = f"""
        SELECT
            c.tipo,
            c.id,
            c.posto,
            c.sub,
            ST_X(c.geom) AS longitude,
            ST_Y(c.geom) AS latitude,
            COUNT(p.id) AS novos_pontos
        FROM candidatos_regiao c
        JOIN pontos_nao_cobertos p
          ON ST_DWithin(
                c.geom::geography,
                p.geom::geography,
                %s
             )
        WHERE 1 = 1
        {filtro_usados}
        GROUP BY
            c.tipo,
            c.id,
            c.posto,
            c.sub,
            c.geom
        ORDER BY novos_pontos DESC
        LIMIT 1;
    """

    cursor.execute(query, parametros)

    return cursor.fetchone()


def marcar_pontos_como_cobertos(cursor, tipo, gateway_id):
    """
    Remove da lista de não cobertos todos os pontos
    alcançados pelo gateway selecionado.
    """

    cursor.execute(
        """
        DELETE FROM pontos_nao_cobertos p
        USING candidatos_regiao c
        WHERE c.tipo = %s
          AND c.id = %s
          AND ST_DWithin(
                c.geom::geography,
                p.geom::geography,
                %s
              );
        """,
        (
            tipo,
            gateway_id,
            ALCANCE_GATEWAY_M,
        ),
    )

    return cursor.rowcount


def contar_nao_cobertos(cursor):
    cursor.execute("SELECT COUNT(*) FROM pontos_nao_cobertos;")
    return cursor.fetchone()[0]


def executar_motor():
    conn = psycopg2.connect(**DB_CONFIG)

    try:
        with conn:
            with conn.cursor() as cursor:

                criar_regiao_teste(cursor)
                criar_pontos_nao_cobertos(cursor)

                total_pontos, total_candidatos = contar_dados(cursor)

                print("\n======================================")
                print(" MOTOR DE COBERTURA - MVP")
                print("======================================")
                print(f"Região: {RAIO_REGIAO_M / 1000:.1f} km")
                print(f"Alcance gateway: {ALCANCE_GATEWAY_M / 1000:.1f} km")
                print(f"Pontos a cobrir: {total_pontos}")
                print(f"Candidatos: {total_candidatos}")
                print("======================================\n")

                selecionados = []
                gateways_usados = set()

                rodada = 1

                while True:

                    restantes = contar_nao_cobertos(cursor)

                    if restantes == 0:
                        break

                    melhor = buscar_melhor_gateway(
                        cursor,
                        gateways_usados,
                    )

                    if melhor is None:
                        print("\nNão existem mais candidatos capazes")
                        print("de cobrir os pontos restantes.")
                        break

                    (
                        tipo,
                        gateway_id,
                        posto,
                        sub,
                        longitude,
                        latitude,
                        ganho_previsto,
                    ) = melhor

                    realmente_cobertos = marcar_pontos_como_cobertos(
                        cursor,
                        tipo,
                        gateway_id,
                    )

                    gateways_usados.add((tipo, gateway_id))

                    restantes = contar_nao_cobertos(cursor)
                    cobertos = total_pontos - restantes

                    percentual = (
                        cobertos / total_pontos * 100
                        if total_pontos
                        else 0
                    )

                    resultado = {
                        "ordem": rodada,
                        "tipo": tipo,
                        "id": gateway_id,
                        "posto": posto,
                        "sub": sub,
                        "latitude": latitude,
                        "longitude": longitude,
                        "novos_pontos": realmente_cobertos,
                        "total_coberto": cobertos,
                        "percentual": percentual,
                    }

                    selecionados.append(resultado)

                    print(
                        f"Gateway {rodada}: "
                        f"{tipo} {gateway_id}"
                    )

                    print(
                        f"  +{realmente_cobertos} novos pontos"
                    )

                    print(
                        f"  Cobertura: "
                        f"{cobertos}/{total_pontos} "
                        f"({percentual:.2f}%)"
                    )

                    print(
                        f"  Restantes: {restantes}"
                    )

                    print()

                    rodada += 1

                print("\n======================================")
                print(" RESULTADO FINAL")
                print("======================================")

                restantes = contar_nao_cobertos(cursor)
                cobertos = total_pontos - restantes

                percentual_final = (
                    cobertos / total_pontos * 100
                    if total_pontos
                    else 0
                )

                print(
                    f"Gateways selecionados: "
                    f"{len(selecionados)}"
                )

                print(
                    f"Pontos cobertos: "
                    f"{cobertos}/{total_pontos}"
                )

                print(
                    f"Cobertura final: "
                    f"{percentual_final:.2f}%"
                )

                print(
                    f"Pontos não cobertos: "
                    f"{restantes}"
                )

                print("\nGateways escolhidos:")

                for g in selecionados:
                    print(
                        f"{g['ordem']:02d}. "
                        f"{g['tipo']} | "
                        f"{g['id']} | "
                        f"{g['percentual']:.2f}% | "
                        f"({g['latitude']}, "
                        f"{g['longitude']})"
                    )

    finally:
        conn.close()


if __name__ == "__main__":
    executar_motor()