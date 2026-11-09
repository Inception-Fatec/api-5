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

# TG-94: carrega o segredo JWT do .env da raiz,
# caso ele ainda nao esteja definido no ambiente.
if [[ -z "${API_SECURITY_TOKEN_SECRET:-}" && -f "$ROOT/.env" ]]; then
  JWT_LINE="$(grep -m1 '^API_SECURITY_TOKEN_SECRET=' "$ROOT/.env" || true)"
  if [[ -n "$JWT_LINE" ]]; then
    export API_SECURITY_TOKEN_SECRET="${JWT_LINE#API_SECURITY_TOKEN_SECRET=}"
  fi
fi

# TG-94: exige o segredo JWT antes de iniciar o backend.
if [[ -z "${API_SECURITY_TOKEN_SECRET:-}" ]]; then
  echo "ERRO: API_SECURITY_TOKEN_SECRET não definida." >&2
  echo "Configure um segredo JWT seguro antes de iniciar o backend." >&2
  exit 1
fi

if [[ "$DB_MODE" == "local" ]]; then
  # host.docker.internal resolve para o host dentro do container (Linux: via host-gateway).
  DB_URL="jdbc:postgresql://tecsys-postgis:5432/tecsys"
  DB_USER="tecsys"
  DB_PASSWORD="tecsys"
  ETL_DB_URL="postgresql+psycopg2://tecsys:tecsys@tecsys-postgis:5432/tecsys"
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
  # O ETL (Python) usa a mesma conexão no formato do SQLAlchemy.
  ETL_DB_URL="postgresql+psycopg2://${REST}"
else
  echo "ERRO: --db aceita apenas 'local' ou 'supabase'."; exit 1
fi

echo "Build da imagem $IMAGE (pode demorar na 1ª vez)..."
# A imagem é montada pelo docker compose: ele leva a pasta modules/ (scripts
# Python do ETL, #TG-103) como contexto extra e já traz o BuildKit. O
# "docker build" comum, sem o plugin buildx, não aceita --build-context (#TG-149).
docker compose -f "$ROOT/docker-compose.yml" build -q backend

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
# Modo supabase: o host direto do Supabase só tem IPv6, que não existe
# na rede bridge padrão do Docker — por isso aqui o container usa a
# rede do host (mesma do `java -jar` fora do Docker). No modo local,
# backend e banco conversam pela rede tecsys-net (nome do container).
if [[ "$DB_MODE" == "supabase" ]]; then
  docker run -d --name "$CONTAINER" --network host \
    -e API_SECURITY_TOKEN_SECRET="$API_SECURITY_TOKEN_SECRET" \
    -e DB_URL="$DB_URL" -e DB_USER="$DB_USER" -e DB_PASSWORD="$DB_PASSWORD" \
    -e ETL_DB_URL="$ETL_DB_URL" -v tecsys-aneel-cache:/var/cache/tecsys-aneel \
    -e ENGINE_URL="http://127.0.0.1:8082/api/calculate" \
    "$IMAGE" >/dev/null
else
  docker network create tecsys-net >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" \
    --network tecsys-net \
    -e API_SECURITY_TOKEN_SECRET="$API_SECURITY_TOKEN_SECRET" \
    -e DB_URL="$DB_URL" \
    -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    -e ETL_DB_URL="$ETL_DB_URL" \
    -v tecsys-aneel-cache:/var/cache/tecsys-aneel \
    -e ENGINE_URL="http://tecsys-motor:8082/api/calculate" \
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
