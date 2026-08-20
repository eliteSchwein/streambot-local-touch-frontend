#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${VERSION:-$(node -p "require('$PROJECT_ROOT/package.json').version")}"
DISTRO="${DISTRO:-trixie}"
ARCH="${ARCH:-all}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/dist-artifacts}"
PACKAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
mkdir -p "$PACKAGE_ROOT/DEBIAN" "$PACKAGE_ROOT/usr/bin" "$PACKAGE_ROOT/usr/share/streambot-touch"
cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: streambot-touch
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: quickshell, qml6-module-qtwebsockets, network-manager, qrencode, iproute2
Maintainer: Thomas Ludwig
Description: Streambot Touch Quickshell interface
 Touch interface for Streambot using Quickshell.
EOF
install -Dm755 "$PROJECT_ROOT/packaging/streambot-touch" "$PACKAGE_ROOT/usr/bin/streambot-touch"
cp -a "$PROJECT_ROOT/src/." "$PACKAGE_ROOT/usr/share/streambot-touch/"
mkdir -p "$OUT_DIR"
OUTPUT="$OUT_DIR/streambot-touch_${VERSION}.${DISTRO}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$PACKAGE_ROOT" "$OUTPUT"
echo "Built: $OUTPUT"
dpkg-deb -f "$OUTPUT" Depends
