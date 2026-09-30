#!/usr/bin/env bash
# Sobe o backend (Spring Boot) num container próprio, na porta 8081.
#
# Uso:
#   ./scripts/run-backend.sh                 # contra o PostGIS local (localhost:5433)
#   ./scripts/run-backend.sh --db supabase   # contra o Supabase (lê Backend/tecsys/.env.supabase)
#   ./scripts/run-backend.sh --stop          # para e remove o container
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER=tecsys-backend
IMAGE=tecsys-backend
PORT=8081
DB_MODE="local"
ENV_FILE="$ROOT/Backend/tecsys/.env.supabase"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB_MODE="$2"; shift 2 ;;
    --stop) docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; echo "Container $CONTAINER parado/removido."; exit 0 ;;
    *) echo "Uso: $0 [--db local|supabase] [--stop]"; exit 1 ;;
  esac
done

if [[ "$DB_MODE" == "local" ]]; then
  # host.docker.internal resolve para o host dentro do container (Linux: via host-gateway).
  DB_URL="jdbc:postgresql://tecsys-postgis:5432/tecsys"
  DB_USER="tecsys"
  DB_PASSWORD="tecsys"
elif [[ "$DB_MODE" == "supabase" ]]; then
  [[ -f "$ENV_FILE" ]] || { echo "ERRO: crie $ENV_FILE a partir do .env.supabase.example e preencha SUPABASE_DB_URL."; exit 1; }
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  # Supabase mostra a string como postgresql:// — libpq aceita tanto
  # postgres:// quanto postgresql://, então aceitamos os dois.
  if [[ "${SUPABASE_DB_URL:-}" == postgres://* ]]; then
    REST="${SUPABASE_DB_URL#postgres://}"
  elif [[ "${SUPABASE_DB_URL:-}" == postgresql://* ]]; then
    REST="${SUPABASE_DB_URL#postgresql://}"
  else
    echo "ERRO: SUPABASE_DB_URL precisa começar com postgres:// ou postgresql://"
    exit 1
  fi
  CREDS="${REST%%@*}"; HOSTDB="${REST#*@}"
  DB_USER="${CREDS%%:*}"; DB_PASSWORD="${CREDS#*:}"
  DB_URL="jdbc:postgresql://${HOSTDB}"
else
  echo "ERRO: --db aceita apenas 'local' ou 'supabase'."; exit 1
fi

echo "Build da imagem $IMAGE (pode demorar na 1ª vez)..."
docker build -q -t "$IMAGE" "$ROOT/Backend/tecsys" >/dev/null

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
# Modo supabase: o host direto do Supabase só tem IPv6, que não existe
# na rede bridge padrão do Docker — por isso aqui o container usa a
# rede do host (mesma do `java -jar` fora do Docker). No modo local,
# bridge + host-gateway basta (PostGIS local é IPv4).
if [[ "$DB_MODE" == "supabase" ]]; then
  docker run -d --name "$CONTAINER" --network host \
    -e DB_URL="$DB_URL" -e DB_USER="$DB_USER" -e DB_PASSWORD="$DB_PASSWORD" \
    "$IMAGE" >/dev/null
else
  docker run -d --name "$CONTAINER" \
    --network tecsys-net \
    -e DB_URL="$DB_URL" \
    -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    -p "$PORT:8081" "$IMAGE" >/dev/null
fi

echo "Aguardando backend responder em :$PORT..."
for _ in $(seq 1 60); do
  curl -s -o /dev/null -X POST "http://localhost:$PORT/api/v1/auth/login" \
    -H 'Content-Type: application/json' -d '{}' && break
  sleep 3
done
curl -s -o /dev/null -w "OK: backend no ar (login responde %{http_code}) — http://localhost:$PORT\n" \
  -X POST "http://localhost:$PORT/api/v1/auth/login" \
  -H 'Content-Type: application/json' -d '{}'
