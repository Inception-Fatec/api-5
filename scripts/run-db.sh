#!/usr/bin/env bash
# Sobe o PostGIS local do projeto (Container tecsys-postgis, porta 5433)
# e restaura o bdgd.dump nele caso esteja vazio.
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
CONTAINER=tecsys-postgis
IMAGE=postgis/postgis:17-3.6-alpine
PORT=5433
DB_USER=tecsys
DB_PASSWORD=tecsys
DB_NAME=tecsys
VOLUME=tecsys-pgdata
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

# O pg_isready pode responder durante o initdb (servidor temporário que
# reinicia em seguida) — só segue quando uma query real passar.
echo "Aguardando banco responder a queries..."
COUNT="empty"
for _ in $(seq 1 20); do
  if COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -p "$PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
    "SELECT count(*) FROM sub;" 2>/dev/null); then
    break
  fi
  COUNT="empty"
  sleep 3
done
if [[ "$COUNT" == "empty" || "$COUNT" == "0" ]]; then
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
  echo "Banco vazio — restaurando $(basename "$DUMP")..."
  docker cp "$DUMP" "$CONTAINER:/tmp/restore.dump"
  docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER" \
    pg_restore -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges /tmp/restore.dump >/dev/null 2>&1 || true
  COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -p "$PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT count(*) FROM sub;" 2>/dev/null || echo "?")
  echo "Restore concluído (sub: $COUNT)."
else
  echo "Banco já populado (sub: $COUNT). Nada a restaurar."
fi

echo "OK: postgres://$DB_USER:****@localhost:$PORT/$DB_NAME"
