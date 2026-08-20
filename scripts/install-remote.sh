#!/bin/bash

set -euo pipefail

REPOSITORY="${STREAMBOT_TOUCH_REPOSITORY:-eliteSchwein/streambot-local-touch-frontend}"
BRANCH="${STREAMBOT_TOUCH_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPOSITORY}/${BRANCH}/scripts"

TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

files=(
    install.sh
    generateService.sh
    StreambotTouch.service
    installLabwcConfig.sh
    installNetworkManagerPolkit.sh
    installPowerPolkit.sh
)

echo "Downloading Streambot Touch installer..."

for file in "${files[@]}"; do
    curl -fsSL "${RAW_BASE}/${file}" -o "${TEMP_DIR}/${file}"
    chmod +x "${TEMP_DIR}/${file}"
done

"${TEMP_DIR}/install.sh" "$@"
