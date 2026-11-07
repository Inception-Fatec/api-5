#!/usr/bin/env bash
# Semeia o mirror local/NAS com tiles do Copernicus DEM GLO-30 (AWS Open Data).
#
# Uso:
#   ./scripts/sync-dem-mirror.sh --mirror-dir /mnt/tecsys-dem-mirror \
#     --bbox -23.37,-22.93,-46.07,-45.53
#
#   ./scripts/sync-dem-mirror.sh --mirror-dir /mnt/tecsys-dem-mirror \
#     --tiles Copernicus_DSM_COG_10_S23_00_W046_00_DEM
#
# O script usa HTTPS público do S3, sem AWS CLI e sem credenciais. Ele grava
# <mirror>/<tile>/<tile>.tif e atualiza <mirror>/manifest.sha256.
set -euo pipefail

BASE_URL="https://copernicus-dem-30m.s3.amazonaws.com"
MIRROR_DIR="${DEM_MIRROR_DIR:-}"
BBOX=""
TILES=""

usage() {
  cat <<'EOF'
Uso:
  ./scripts/sync-dem-mirror.sh --mirror-dir /mnt/tecsys-dem-mirror \
    --bbox -23.37,-22.93,-46.07,-45.53

  ./scripts/sync-dem-mirror.sh --mirror-dir /mnt/tecsys-dem-mirror \
    --tiles Copernicus_DSM_COG_10_S23_00_W046_00_DEM

O script usa HTTPS público do S3, sem AWS CLI e sem credenciais. Ele grava
<mirror>/<tile>/<tile>.tif e atualiza <mirror>/manifest.sha256.
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mirror-dir) MIRROR_DIR="${2:-}"; shift 2 ;;
    --bbox) BBOX="${2:-}"; shift 2 ;;
    --tiles) TILES="${2:-}"; shift 2 ;;
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERRO: argumento desconhecido: $1"; usage ;;
  esac
done

[[ -n "$MIRROR_DIR" ]] || { echo "ERRO: informe --mirror-dir ou DEM_MIRROR_DIR."; exit 1; }
[[ -n "$BBOX" || -n "$TILES" ]] || { echo "ERRO: informe --bbox ou --tiles."; exit 1; }
[[ -z "$BBOX" || -z "$TILES" ]] || { echo "ERRO: use --bbox ou --tiles, não os dois."; exit 1; }

for cmd in curl awk sha256sum od realpath; do
  command -v "$cmd" >/dev/null || { echo "ERRO: comando obrigatório não encontrado: $cmd"; exit 1; }
done

MIRROR_DIR="$(realpath -m "$MIRROR_DIR")"
mkdir -p "$MIRROR_DIR"

tile_name() {
  local lat="$1" lon="$2"
  local ns="N" ew="E"
  (( lat < 0 )) && ns="S"
  (( lon < 0 )) && ew="W"
  printf 'Copernicus_DSM_COG_10_%s%02d_00_%s%03d_00_DEM\n' "$ns" "${lat#-}" "$ew" "${lon#-}"
}

floor_deg() {
  awk -v x="$1" 'BEGIN { print (x < 0 && x != int(x)) ? int(x) - 1 : int(x) }'
}

ceil_deg() {
  awk -v x="$1" 'BEGIN { print (x > 0 && x != int(x)) ? int(x) + 1 : int(x) }'
}

tiles_from_bbox() {
  local south="$1" north="$2" west="$3" east="$4"
  local lat lat0 lat1 lon lon0 lon1
  lat0="$(floor_deg "$south")"
  lat1=$(( $(ceil_deg "$north") - 1 ))
  lon0="$(floor_deg "$west")"
  lon1=$(( $(ceil_deg "$east") - 1 ))
  for (( lat = lat0; lat <= lat1; lat++ )); do
    for (( lon = lon0; lon <= lon1; lon++ )); do
      tile_name "$lat" "$lon"
    done
  done
}

if [[ -n "$BBOX" ]]; then
  IFS=, read -r SOUTH NORTH WEST EAST <<< "$BBOX"
  for value in "$SOUTH" "$NORTH" "$WEST" "$EAST"; do
    [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || { echo "ERRO: bbox inválida: $BBOX"; exit 1; }
  done
  awk -v s="$SOUTH" -v n="$NORTH" -v w="$WEST" -v e="$EAST" 'BEGIN {
    exit !(s >= -50 && n <= 50 && w >= -180 && e <= 180 && s < n && w < e)
  }' || { echo "ERRO: bbox fora do domínio suportado (lat -50..50, lon -180..180, sem antimeridiano)."; exit 1; }
  mapfile -t TILE_LIST < <(tiles_from_bbox "$SOUTH" "$NORTH" "$WEST" "$EAST")
else
  IFS=, read -ra TILE_LIST <<< "$TILES"
fi

[[ ${#TILE_LIST[@]} -gt 0 ]] || { echo "ERRO: nenhum tile calculado."; exit 1; }

is_tiff() {
  local magic
  magic="$(od -An -tx1 -N4 "$1" | tr -d ' \n')"
  [[ "$magic" == "49492a00" || "$magic" == "4d4d002a" ]]
}

echo "Mirror: $MIRROR_DIR"
echo "Base:   $BASE_URL"
echo "Tiles:  ${#TILE_LIST[@]}"

for tile in "${TILE_LIST[@]}"; do
  [[ "$tile" =~ ^Copernicus_DSM_COG_10_[NS][0-9]{2}_00_[EW][0-9]{3}_00_DEM$ ]] \
    || { echo "ERRO: nome de tile inválido: $tile"; exit 1; }

  target="$MIRROR_DIR/$tile/$tile.tif"
  if [[ -s "$target" ]] && is_tiff "$target"; then
    echo "OK   $tile (já existe)"
    continue
  fi

  mkdir -p "$MIRROR_DIR/$tile"
  part="$target.part"
  rm -f "$part"
  url="$BASE_URL/$tile/$tile.tif"
  echo "BAIXANDO $tile"
  if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o "$part" "$url"; then
    rm -f "$part"
    echo "ERRO: falha ao baixar $url"
    exit 1
  fi
  if ! is_tiff "$part"; then
    rm -f "$part"
    echo "ERRO: conteúdo baixado não é um TIFF: $url"
    exit 1
  fi
  mv -f "$part" "$target"
  echo "OK   $tile"
done

(
  cd "$MIRROR_DIR"
  for f in */*.tif; do
    [[ -f "$f" ]] || continue
    sha256sum "$f"
  done > manifest.sha256
)

echo "Manifesto: $MIRROR_DIR/manifest.sha256"
echo "Pronto."
