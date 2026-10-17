#!/usr/bin/env bash
# Sobe a stack inteira com o BANCO LOCAL (PostGIS em container).
#
# Uso:
#   ./scripts/up-local.sh         # db + backend + frontend
#   ./scripts/up-local.sh --stop  # para os 3 (dados ficam no volume)
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

stop_all() {
  "$SCRIPTS/run-frontend.sh" --stop
  "$SCRIPTS/run-backend.sh" --stop
  "$SCRIPTS/run-db.sh" --stop
}

if [[ "${1:-}" == "--stop" ]]; then
  stop_all
  exit 0
fi

echo "=== [1/3] banco local ==="
"$SCRIPTS/run-db.sh"
echo "=== [2/3] backend (db local) ==="
"$SCRIPTS/run-backend.sh"
echo "=== [3/3] frontend ==="
"$SCRIPTS/run-frontend.sh"

cat <<'EOF'

Stack local no ar:
  app:     http://localhost:8080  (login: admin@tecsys.com.br / admin123)
  api:     http://localhost:8081
  banco:   postgres://tecsys:tecsys@localhost:5433/tecsys
Parar tudo: ./scripts/up-local.sh --stop
EOF
