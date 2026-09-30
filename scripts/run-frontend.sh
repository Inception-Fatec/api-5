#!/usr/bin/env bash
# Sobe o frontend (Flutter web) num container nginx próprio, na porta 8080.
# A URL da API é embutida no build — se o backend estiver em outro
# host/porta, informe aqui (exige rebuild, é assim que o Flutter web funciona).
#
# Uso:
#   ./scripts/run-frontend.sh                                  # API em localhost:8081
#   ./scripts/run-frontend.sh --api-host 192.168.0.10         # backend noutra máquina
#   ./scripts/run-frontend.sh --api-host localhost --api-port 8081
#   ./scripts/run-frontend.sh --stop                           # para e remove o container
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER=tecsys-frontend
IMAGE=tecsys-frontend
PORT=8080
API_HOST="localhost"
API_PORT="8081"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-host) API_HOST="$2"; shift 2 ;;
    --api-port) API_PORT="$2"; shift 2 ;;
    --stop) docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; echo "Container $CONTAINER parado/removido."; exit 0 ;;
    *) echo "Uso: $0 [--api-host HOST] [--api-port PORT] [--stop]"; exit 1 ;;
  esac
done

echo "Build da imagem $IMAGE com API em $API_HOST:$API_PORT (pode demorar na 1ª vez)..."
docker build -q -t "$IMAGE" \
  --build-arg "API_HOST=$API_HOST" --build-arg "API_PORT=$API_PORT" \
  "$ROOT/Frontend" >/dev/null

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" -p "$PORT:80" "$IMAGE" >/dev/null

sleep 3
curl -s -o /dev/null -w "OK: frontend no ar — http://localhost:$PORT (API: $API_HOST:$API_PORT)\n" "http://localhost:$PORT/"
