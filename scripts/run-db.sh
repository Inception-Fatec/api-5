#!/usr/bin/env bash
# Sobe o PostGIS local do projeto (Container tecsys-postgis, porta 5433)
# e, se estiver vazio, cria as tabelas pelas migrations do Flyway e carrega
# os dados da rede do bdgd.dump (#TG-142). Também funciona com o banco do
# docker compose: docker compose up -d db && ./scripts/run-db.sh && docker compose up -d
#
# Uso:
#   ./scripts/run-db.sh                 # sobe + restaura se vazio
#   ./scripts/run-db.sh --dump ~/x.dump # idem, com outro dump
#   ./scripts/run-db.sh --stop          # para e remove o container (dados ficam no volume)
#
# Onde o script procura o dump (nesta ordem):
#   1. --dump CAMINHO
#   2. api-5/db/bdgd.dump  (convenção: coloque seu dump aqui)
#   3. ~/Documents/bdgd.dump (legado)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER=${TECSYS_DB_CONTAINER:-tecsys-postgis}
IMAGE=postgis/postgis:17-3.6-alpine
PORT=${TECSYS_DB_PORT:-5433}
DB_USER=tecsys
DB_PASSWORD=tecsys
DB_NAME=tecsys
VOLUME=${TECSYS_DB_VOLUME:-tecsys-pgdata}
# Mesma versão do Flyway do Spring Boot do backend (3.3.4 -> Flyway 10.10.0).
FLYWAY_IMAGE=flyway/flyway:10.10.0-alpine
DUMP=""
DUMP_FLAG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dump) DUMP="$2"; DUMP_FLAG=1; shift 2 ;;
    --stop) docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; echo "Container $CONTAINER parado/removido (volume $VOLUME preservado)."; exit 0 ;;
    *) echo "Uso: $0 [--dump CAMINHO] [--stop]"; exit 1 ;;
  esac
done

# Resolve o dump: flag > db/bdgd.dump > ~/Documents/bdgd.dump.
if [[ "$DUMP_FLAG" == "0" ]]; then
  if [[ -f "$ROOT/db/bdgd.dump" ]]; then
    DUMP="$ROOT/db/bdgd.dump"
  else
    DUMP="$HOME/Documents/bdgd.dump"
  fi
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker network create tecsys-net >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" \
    --network tecsys-net \
    -e POSTGRES_USER="$DB_USER" -e POSTGRES_PASSWORD="$DB_PASSWORD" -e POSTGRES_DB="$DB_NAME" \
    -p "$PORT:5432" -v "$VOLUME:/var/lib/postgresql/data" \
    "$IMAGE" >/dev/null
  echo "Subindo $CONTAINER... aguardando aceitar conexões."
  until docker exec "$CONTAINER" pg_isready -U "$DB_USER" >/dev/null 2>&1; do sleep 2; done
else
  echo "Container $CONTAINER já está rodando."
  # Garante que o backend (rede tecsys-net) enxerga o banco pelo nome.
  docker network create tecsys-net >/dev/null 2>&1 || true
  docker network connect tecsys-net "$CONTAINER" >/dev/null 2>&1 || true
fi

# Consultas rodam dentro do container (não depende de psql instalado na máquina).
# Via TCP (-h 127.0.0.1): durante o initdb o Postgres sobe um servidor
# temporário que só escuta no socket local e reinicia em seguida; pelo TCP a
# query só passa quando o servidor definitivo está no ar.
q() { docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -tAc "$1"; }

# Só segue quando uma query real passar (ver acima).
echo "Aguardando banco responder a queries..."
for _ in $(seq 1 30); do
  q "SELECT 1" >/dev/null 2>&1 && break
  sleep 2
done

# Volume antigo, montado com o dump inteiro antes das migrations (#TG-142):
# tem tabelas mas não tem o histórico do Flyway, e o backend não sobe nele.
if [[ "$(q "SELECT to_regclass('flyway_schema_history') IS NULL AND to_regclass('users') IS NOT NULL")" == "t" ]]; then
  cat >&2 <<EOF
ERRO: o banco do volume tem tabelas mas não tem o histórico do Flyway
(foi montado com o dump antigo) e o backend não sobe nele. Recrie o volume:
  ./scripts/run-db.sh --stop && docker volume rm $VOLUME && ./scripts/run-db.sh
EOF
  exit 1
fi

COUNT=0
if [[ "$(q "SELECT to_regclass('sub') IS NOT NULL")" == "t" ]]; then
  COUNT=$(q "SELECT count(*) FROM sub")
fi
if [[ "$COUNT" != "0" ]]; then
  echo "Banco já populado (sub: $COUNT). Nada a restaurar."
  echo "OK: postgres://$DB_USER:****@localhost:$PORT/$DB_NAME"
  exit 0
fi

if [[ ! -f "$DUMP" ]]; then
  cat >&2 <<EOF
ERRO: banco vazio e dump não encontrado.
Procurei em: $DUMP
Para subir pela 1ª vez você precisa do arquivo bdgd.dump:
  1. pegue o dump com a equipe e coloque em $ROOT/db/bdgd.dump, ou
  2. rode com --dump CAMINHO/para/seu-bdgd.dump
(Após o primeiro restore os dados ficam no volume Docker e o dump não é mais necessário.)
EOF
  exit 1
fi

# 1) Estrutura: as mesmas migrations do backend (Flyway na mesma versão do
#    Spring Boot), para o backend encontrar o banco já em dia ao subir.
echo "Criando as tabelas (migrations do Flyway)..."
docker run --rm --network tecsys-net \
  -v "$ROOT/Backend/tecsys/src/main/resources/db/migration:/flyway/sql:ro" \
  "$FLYWAY_IMAGE" -url="jdbc:postgresql://$CONTAINER:5432/$DB_NAME" \
  -user="$DB_USER" -password="$DB_PASSWORD" -baselineOnMigrate=true migrate \
  | grep -E "Successfully|up to date|ERROR" || true

# 2) Dados: só as tabelas da rede elétrica do dump. users vem da V9 (admin)
#    e spatial_ref_sys vem da extensão PostGIS.
echo "Restaurando os dados da rede de $(basename "$DUMP")..."
docker cp "$DUMP" "$CONTAINER:/tmp/restore.dump"
TABELAS=$(docker exec "$CONTAINER" pg_restore -l /tmp/restore.dump \
  | awk '/ TABLE DATA public / {print $(NF-1)}' | grep -vxE 'users|spatial_ref_sys' || true)
ARGS=()
for t in $TABELAS; do ARGS+=(-t "$t"); done
docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER" \
  pg_restore -U "$DB_USER" -d "$DB_NAME" --data-only --disable-triggers --no-owner --no-privileges \
  "${ARGS[@]}" /tmp/restore.dump
docker exec "$CONTAINER" sh -c 'rm -f /tmp/restore.dump'
echo "Restore concluído ($(echo $TABELAS | wc -w) tabelas; sub: $(q "SELECT count(*) FROM sub"))."

echo "OK: postgres://$DB_USER:****@localhost:$PORT/$DB_NAME"
