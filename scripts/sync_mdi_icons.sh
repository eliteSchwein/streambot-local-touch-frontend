#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ICONS=(
  home
  plus
  minus
  volume-high
  volume-off
  link-variant
)

cd "$TMP"
npm init -y >/dev/null
npm install --ignore-scripts --no-audit --no-fund @mdi/svg@7.4.47 >/dev/null

mkdir -p "$ROOT/src/icons/mdi"

for icon in "${ICONS[@]}"; do
  cp \
    "$TMP/node_modules/@mdi/svg/svg/$icon.svg" \
    "$ROOT/src/icons/mdi/$icon.svg"
done

cp \
  "$TMP/node_modules/@mdi/svg/LICENSE" \
  "$ROOT/src/icons/mdi/LICENSE.upstream"

echo "Synced MDI SVG subset."
