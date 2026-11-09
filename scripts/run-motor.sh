#!/usr/bin/env bash
# Sobe o motor de decisão (Spring Boot) num container próprio, na porta 8082.
#
# Uso:
#   ./scripts/run-motor.sh                 # contra o PostGIS local (tecsys-postgis)
#   ./scripts/run-motor.sh --db supabase   # contra o Supabase (lê MOTOR/.env.supabase)
#   ./scripts/run-motor.sh --stop          # para e remove o container
#
# Relevo: os tiles do Copernicus GLO-30 baixados do AWS Open Data ficam no
# volume Docker tecsys-dem-cache, que sobrevive ao container. Não há chave
# de API. Para usar um mirror local/NAS, defina DEM_MIRROR_DIR no arquivo
# de ambiente; o script monta esse diretório read-only no container.
#
# Parâmetros do motor: qualquer linha MOTOR_*=valor ou DEM_*=valor do
# arquivo de ambiente (ex.: MOTOR_PROFILE=tecsys, DEM_DOWNLOAD_ATTEMPTS=4)
# é repassada ao container. Ver MOTOR/README.md.
#
# Configurações:
#   Lidas EXCLUSIVAMENTE de arquivos dentro de MOTOR/:
#   - Modo local:    MOTOR/.env.properties
#   - Modo Supabase: MOTOR/.env.supabase
#
# O motor NÃO tem autenticação: ele só escuta em 127.0.0.1 (host). Quem
# chama é o backend — pelo localhost (modo supabase, rede do host) ou pelo
# nome tecsys-motor (modo local, rede tecsys-net).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER=tecsys-motor
IMAGE=tecsys-motor
PORT=8082
DB_MODE="local"
MOTOR_ENV_LOCAL="$ROOT/MOTOR/.env.properties"
MOTOR_ENV_SUPABASE="$ROOT/MOTOR/.env.supabase"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB_MODE="${2:-}"; shift 2 ;;
    --stop) docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; echo "Container $CONTAINER parado/removido."; exit 0 ;;
    *) echo "Uso: $0 [--db local|supabase] [--stop]"; exit 1 ;;
  esac
done

# Função auxiliar para extrair chave=valor de um arquivo de configuração do MOTOR
get_motor_env() {
  local key="$1"
  local target_file="$2"
  if [[ -f "$target_file" ]]; then
    grep -E "^${key}=" "$target_file" | head -1 | cut -d= -f2- | tr -d '\r"' || true
  fi
}

if [[ "$DB_MODE" == "local" ]]; then
  DB_URL="jdbc:postgresql://tecsys-postgis:5432/tecsys"
  DB_USER="tecsys"
  DB_PASSWORD="tecsys"

elif [[ "$DB_MODE" == "supabase" ]]; then
  [[ -f "$MOTOR_ENV_SUPABASE" ]] || { echo "ERRO: crie $MOTOR_ENV_SUPABASE com as credenciais e preencha SUPABASE_DB_URL."; exit 1; }

  SUPABASE_DB_URL="$(get_motor_env "SUPABASE_DB_URL" "$MOTOR_ENV_SUPABASE")"

  if [[ -z "$SUPABASE_DB_URL" ]]; then
    echo "ERRO: SUPABASE_DB_URL não encontrada em $MOTOR_ENV_SUPABASE"
    exit 1
  fi

  if [[ "$SUPABASE_DB_URL" == postgres://* ]]; then
    REST="${SUPABASE_DB_URL#postgres://}"
  elif [[ "$SUPABASE_DB_URL" == postgresql://* ]]; then
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

ENV_FILE="$MOTOR_ENV_LOCAL"
[[ "$DB_MODE" == "supabase" ]] && ENV_FILE="$MOTOR_ENV_SUPABASE"
MOTOR_ARGS=()
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line; do
    MOTOR_ARGS+=(-e "$line")
  done < <(grep -E '^(MOTOR|DEM)_[A-Z0-9_]+=' "$ENV_FILE" | grep -vE '^(MOTOR_(PORT|BIND_ADDRESS)|DEM_(CACHE_DIR|MIRROR_DIR))=' | tr -d '\r"')
fi

MIRROR_HOST_DIR="$(get_motor_env "DEM_MIRROR_DIR" "$ENV_FILE")"
MIRROR_ARGS=()
if [[ -n "$MIRROR_HOST_DIR" ]]; then
  [[ "$MIRROR_HOST_DIR" == /* ]] || MIRROR_HOST_DIR="$ROOT/$MIRROR_HOST_DIR"
  MIRROR_HOST_DIR="$(realpath -m "$MIRROR_HOST_DIR")"
  if [[ -d "$MIRROR_HOST_DIR" ]]; then
    MIRROR_ARGS=(-v "${MIRROR_HOST_DIR}:/var/cache/tecsys-dem-mirror:ro" -e DEM_MIRROR_DIR=/var/cache/tecsys-dem-mirror)
  else
    echo "AVISO: DEM_MIRROR_DIR=$MIRROR_HOST_DIR não existe ou não é diretório; seguindo sem mirror."
  fi
fi
DEM_VOLUME=(-v tecsys-dem-cache:/var/cache/tecsys-dem)

echo "Build da imagem $IMAGE (pode demorar na 1ª vez)..."
docker build -q -t "$IMAGE" "$ROOT/MOTOR" >/dev/null

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

if [[ "$DB_MODE" == "supabase" ]]; then
  docker run -d --name "$CONTAINER" --network host \
    -e DB_URL="$DB_URL" -e DB_USER="$DB_USER" -e DB_PASSWORD="$DB_PASSWORD" \
    -e MOTOR_PORT="$PORT" \
    "${DEM_VOLUME[@]}" ${MIRROR_ARGS[@]+"${MIRROR_ARGS[@]}"} ${MOTOR_ARGS[@]+"${MOTOR_ARGS[@]}"} \
    "$IMAGE" >/dev/null
else
  docker network create tecsys-net >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" \
    --network tecsys-net \
    -e DB_URL="$DB_URL" -e DB_USER="$DB_USER" -e DB_PASSWORD="$DB_PASSWORD" \
    -e MOTOR_BIND_ADDRESS=0.0.0.0 \
    "${DEM_VOLUME[@]}" ${MIRROR_ARGS[@]+"${MIRROR_ARGS[@]}"} ${MOTOR_ARGS[@]+"${MOTOR_ARGS[@]}"} \
    -p "127.0.0.1:$PORT:8082" "$IMAGE" >/dev/null
fi

echo "Aguardando motor responder em :$PORT..."
code=000
for _ in $(seq 1 40); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)"
  [[ "$code" != "000" ]] && break
  docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" || break
  sleep 3
done

if [[ "$code" == "000" ]]; then
  echo "ERRO: o motor não respondeu. Últimas linhas do log:"
  docker logs --tail 40 "$CONTAINER" || true
  exit 1
fi
echo "OK: motor no ar (GET / responde $code) — http://127.0.0.1:$PORT"