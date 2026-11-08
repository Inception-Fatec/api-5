# ---- stage 1: build do jar ----
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -q -DskipTests package

# ---- stage 2: runtime (JRE + Python do ETL) ----
# O upload de geodatabase roda o ETL em Python (modules/etl_cli.py) como
# subprocesso do backend (#TG-103). Base Ubuntu (glibc) para o pip usar as
# wheels prontas de geopandas/pyogrio/pyproj; Python 3.12, igual ao do venv.
FROM eclipse-temurin:17-jre-noble
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

# Dependências do ETL num venv próprio. Os arquivos vêm do contexto nomeado
# "modules" (pasta modules/ da raiz), passado pelo docker-compose
# (additional_contexts) ou pelo scripts/run-backend.sh (--build-context).
COPY --from=modules requirements.txt /tmp/requirements-etl.txt
RUN python3 -m venv /opt/etl-venv \
 && /opt/etl-venv/bin/pip install --no-cache-dir -r /tmp/requirements-etl.txt \
 && rm /tmp/requirements-etl.txt
COPY --from=modules *.py /app/modules/

WORKDIR /app
COPY --from=build /app/target/tecsys-*.jar app.jar

# ETL_DB_URL (banco onde o ETL grava, formato SQLAlchemy) vem do compose ou
# do run-backend.sh. CACHE_DIR guarda os CSVs da ANEEL baixados pelo ETL e
# deve ser um volume para não baixar de novo a cada container.
ENV ETL_PYTHON=/opt/etl-venv/bin/python \
    ETL_SCRIPT_PATH=/app/modules/etl_cli.py \
    CACHE_DIR=/var/cache/tecsys-aneel

EXPOSE 8081
# Conexão com o banco vem por variáveis de ambiente (DB_URL, DB_USER,
# DB_PASSWORD) — ver scripts/run-backend.sh. Não embarcar .env na imagem.
ENTRYPOINT ["java", "-jar", "app.jar"]
