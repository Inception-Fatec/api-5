#!/usr/bin/env bash
# Sobe a stack inteira com o BANCO NO SUPABASE (não sobe PostGIS local).
#
# Pré-requisito: Backend/tecsys/.env.supabase preenchido a partir do
# .env.supabase.example (ver Backend/tecsys/DOCKER.md).
#
# Uso:
#   ./scripts/up-supabase.sh         # backend (nuvem) + motor + frontend
#   ./scripts/up-supabase.sh --stop  # para os 3
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$(cd "$SCRIPTS/../Backend/tecsys" && pwd)/.env.supabase"

stop_all() {
  "$SCRIPTS/run-frontend.sh" --stop
  "$SCRIPTS/run-motor.sh" --stop
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

echo "=== [1/3] backend (db supabase) ==="
"$SCRIPTS/run-backend.sh" --db supabase
# O motor sobe depois do backend: é o backend que cria a tabela
# project_coverage (Hibernate) no primeiro boot.
echo "=== [2/3] motor (db supabase) ==="
"$SCRIPTS/run-motor.sh" --db supabase
echo "=== [3/3] frontend ==="
"$SCRIPTS/run-frontend.sh"

cat <<'EOT'

Stack (banco na nuvem) no ar:
  app:     http://localhost:8080  (login: admin@tecsys.com.br / admin123)
  api:     http://localhost:8081
  motor:   http://127.0.0.1:8082  (interno — só o backend chama)
  banco:   Supabase (ver SUPABASE_DB_URL em Backend/tecsys/.env.supabase)
Parar tudo: ./scripts/up-supabase.sh --stop
EOT
