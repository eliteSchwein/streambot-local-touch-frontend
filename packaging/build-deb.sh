#!/bin/bash
set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
DISTRO="${DISTRO:-trixie}"
ARCH="${ARCH:-all}"
OUT_DIR="${OUT_DIR:-dist-artifacts}"

PACKAGE_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$PACKAGE_ROOT"
}

trap cleanup EXIT

mkdir -p \
    "$PACKAGE_ROOT/DEBIAN" \
    "$PACKAGE_ROOT/usr/bin" \
    "$PACKAGE_ROOT/usr/share/streambot-touch"

cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: streambot-touch
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: quickshell, qml6-module-qtwebsockets
Maintainer: Thomas Ludwig
Description: Streambot Touch Quickshell interface
 Touch interface for Streambot using Quickshell.
EOF

install -Dm755 \
    packaging/streambot-touch \
    "$PACKAGE_ROOT/usr/bin/streambot-touch"

cp -a src/. \
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
echo "Package info:"
dpkg-deb --info "$OUTPUT"

echo
echo "Package contents:"
dpkg-deb --contents "$OUTPUT"

echo
echo "Dependencies:"
dpkg-deb -f "$OUTPUT" Depends