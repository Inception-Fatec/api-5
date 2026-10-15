#!/usr/bin/env bash
# Sobe a stack inteira com o BANCO NO SUPABASE (não sobe PostGIS local).
#
# Pré-requisito: Backend/tecsys/.env.supabase preenchido a partir do
# .env.supabase.example (ver Backend/tecsys/DOCKER.md).
#
# Uso:
#   ./scripts/up-supabase.sh         # backend (nuvem) + frontend
#   ./scripts/up-supabase.sh --stop  # para os 2
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$(cd "$SCRIPTS/../Backend/tecsys" && pwd)/.env.supabase"

stop_all() {
  "$SCRIPTS/run-frontend.sh" --stop
  "$SCRIPTS/run-backend.sh" --stop
}

if [[ "${1:-}" == "--stop" ]]; then
  stop_all
  exit 0
fi

[[ -f "$ENV_FILE" ]] || {
  echo "ERRO: $ENV_FILE não existe."
  echo "Copie Backend/tecsys/.env.supabase.example para .env.supabase e preencha SUPABASE_DB_URL."
  exit 1
}

echo "=== [1/2] backend (db supabase) ==="
"$SCRIPTS/run-backend.sh" --db supabase
echo "=== [2/2] frontend ==="
"$SCRIPTS/run-frontend.sh"

cat <<'EOF'

Stack (banco na nuvem) no ar:
  app:     http://localhost:8080  (login: admin@tecsys.com.br / admin123)
  api:     http://localhost:8081
  banco:   Supabase (ver SUPABASE_DB_URL em Backend/tecsys/.env.supabase)
Parar tudo: ./scripts/up-supabase.sh --stop
EOF
