#!/usr/bin/env bash
# Sobe a stack inteira com o BANCO LOCAL (PostGIS em container).
#
# Uso:
#   ./scripts/up-local.sh         # db + backend + motor + frontend
#   ./scripts/up-local.sh --stop  # para os 4 (dados ficam no volume)
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

stop_all() {
  "$SCRIPTS/run-frontend.sh" --stop
  "$SCRIPTS/run-motor.sh" --stop
  "$SCRIPTS/run-backend.sh" --stop
  "$SCRIPTS/run-db.sh" --stop
}

if [[ "${1:-}" == "--stop" ]]; then
  stop_all
  exit 0
fi

echo "=== [1/4] banco local ==="
"$SCRIPTS/run-db.sh"
echo "=== [2/4] backend (db local) ==="
"$SCRIPTS/run-backend.sh"
# O motor sobe depois do backend: é o backend que cria a tabela
# project_coverage (Hibernate) no primeiro boot.
echo "=== [3/4] motor (db local) ==="
"$SCRIPTS/run-motor.sh"
echo "=== [4/4] frontend ==="
"$SCRIPTS/run-frontend.sh"

cat <<'EOT'

Stack local no ar:
  app:     http://localhost:8080  (login: admin@tecsys.com.br / admin123)
  api:     http://localhost:8081
  motor:   http://127.0.0.1:8082  (interno — só o backend chama)
  banco:   postgres://tecsys:tecsys@localhost:5433/tecsys
Parar tudo: ./scripts/up-local.sh --stop
EOT
