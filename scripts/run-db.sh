#!/usr/bin/env bash
# Sobe o PostGIS local do projeto (Container tecsys-postgis, porta 5433)
# e restaura o bdgd.dump nele caso esteja vazio.
#
# Uso:
#   ./scripts/run-db.sh                 # sobe + restaura se vazio
#   ./scripts/run-db.sh --dump ~/x.dump # idem, com outro dump
#   ./scripts/run-db.sh --stop          # para e remove o container (dados ficam no volume)
set -euo pipefail

CONTAINER=tecsys-postgis
IMAGE=postgis/postgis:17-3.6-alpine
PORT=5433
DB_USER=tecsys
DB_PASSWORD=tecsys
DB_NAME=tecsys
VOLUME=tecsys-pgdata
DUMP="$HOME/Documents/bdgd.dump"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dump) DUMP="$2"; shift 2 ;;
    --stop) docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; echo "Container $CONTAINER parado/removido (volume $VOLUME preservado)."; exit 0 ;;
    *) echo "Uso: $0 [--dump CAMINHO] [--stop]"; exit 1 ;;
  esac
done

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" \
    -e POSTGRES_USER="$DB_USER" -e POSTGRES_PASSWORD="$DB_PASSWORD" -e POSTGRES_DB="$DB_NAME" \
    -p "$PORT:5432" -v "$VOLUME:/var/lib/postgresql/data" \
    "$IMAGE" >/dev/null
  echo "Subindo $CONTAINER... aguardando aceitar conexões."
  until docker exec "$CONTAINER" pg_isready -U "$DB_USER" >/dev/null 2>&1; do sleep 2; done
else
  echo "Container $CONTAINER já está rodando."
fi

# Restaura o dump só se a tabela 'sub' estiver ausente/vazia.
COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -p "$PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
  "SELECT count(*) FROM sub;" 2>/dev/null || echo "empty")
if [[ "$COUNT" == "empty" || "$COUNT" == "0" ]]; then
  [[ -f "$DUMP" ]] || { echo "ERRO: dump não encontrado em $DUMP (use --dump)."; exit 1; }
  echo "Banco vazio — restaurando $(basename "$DUMP")..."
  docker cp "$DUMP" "$CONTAINER:/tmp/restore.dump"
  docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER" \
    pg_restore -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges /tmp/restore.dump >/dev/null 2>&1 || true
  COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -p "$PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT count(*) FROM sub;")
  echo "Restore concluído (sub: $COUNT)."
else
  echo "Banco já populado (sub: $COUNT). Nada a restaurar."
fi

echo "OK: postgres://$DB_USER:****@localhost:$PORT/$DB_NAME"
