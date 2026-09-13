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
matugen -c "$CONFIG" image "$IMAGE"
echo "generated palette from $IMAGE"
