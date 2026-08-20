#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PACKAGE_JSON="$PROJECT_ROOT/package.json"

if [[ ! -f "$PACKAGE_JSON" ]]; then
    echo "package.json not found: $PACKAGE_JSON" >&2
    exit 1
fi

VERSION="${VERSION:-$(node -p "require('$PACKAGE_JSON').version")}"
DISTRO="${DISTRO:-trixie}"
ARCH="${ARCH:-all}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/dist-artifacts}"

PACKAGE_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$PACKAGE_ROOT"
}

trap cleanup EXIT

mkdir -p \
    "$PACKAGE_ROOT/DEBIAN" \
    "$PACKAGE_ROOT/usr/bin" \
    "$PACKAGE_ROOT/usr/lib/streambot-touch" \
    "$PACKAGE_ROOT/usr/share/streambot-touch"

cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: streambot-touch
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: quickshell, qml6-module-qtwebsockets, network-manager, qrencode, iproute2, python3
Maintainer: Thomas Ludwig
Description: Streambot Touch Quickshell interface
 Touch interface for Streambot using Quickshell.
EOF

install -Dm755 \
    "$PROJECT_ROOT/packaging/streambot-touch" \
    "$PACKAGE_ROOT/usr/bin/streambot-touch"

install -Dm755 \
    "$PROJECT_ROOT/helper/power_key_listener.py" \
    "$PACKAGE_ROOT/usr/lib/streambot-touch/power-key-listener"

cp -a \
    "$PROJECT_ROOT/src/." \
    "$PACKAGE_ROOT/usr/share/streambot-touch/"

mkdir -p "$OUT_DIR"

OUTPUT="$OUT_DIR/streambot-touch_${VERSION}.${DISTRO}_${ARCH}.deb"

dpkg-deb \
    --root-owner-group \
    --build \
    "$PACKAGE_ROOT" \
    "$OUTPUT"

echo
echo "Built:"
echo "$OUTPUT"

echo
echo "Dependencies:"
dpkg-deb -f "$OUTPUT" Depends
