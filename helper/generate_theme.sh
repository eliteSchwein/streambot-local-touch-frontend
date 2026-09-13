#!/bin/bash
set -euo pipefail

IMAGE="${1:-}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/streambot-touch"
CONFIG="/usr/share/streambot-touch/matugen/config.toml"

if [[ -z "$IMAGE" || ! -f "$IMAGE" ]]; then
    echo "wallpaper does not exist: $IMAGE" >&2
    exit 1
fi

mkdir -p "$CACHE_DIR"

MATUGEN_BIN="$(command -v matugen 2>/dev/null || true)"
if [[ -z "$MATUGEN_BIN" && -x /usr/local/bin/matugen ]]; then
    MATUGEN_BIN=/usr/local/bin/matugen
fi

if [[ -z "$MATUGEN_BIN" && -x "$HOME/.cargo/bin/matugen" ]]; then
    MATUGEN_BIN="$HOME/.cargo/bin/matugen"
fi

if [[ -z "$MATUGEN_BIN" ]]; then
    echo "matugen is not installed" >&2
    exit 1
fi

echo "using $($MATUGEN_BIN --version 2>/dev/null || echo "$MATUGEN_BIN")"
"$MATUGEN_BIN" -c "$CONFIG" image --source-color-index 0 "$IMAGE"

THEME_FILE="$CACHE_DIR/theme.json"
if [[ ! -s "$THEME_FILE" ]]; then
    echo "matugen did not create $THEME_FILE" >&2
    exit 1
fi

echo "generated palette: $THEME_FILE"
echo "generated palette from $IMAGE"
