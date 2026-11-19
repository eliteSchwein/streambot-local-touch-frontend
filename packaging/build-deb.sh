#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${VERSION:-$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["package"]["version"])' "$PROJECT_ROOT/Cargo.toml")}"
DISTRO="${DISTRO:-$(. /etc/os-release && echo "$VERSION_CODENAME")}"
ARCH="$(dpkg --print-architecture)"
cd "$PROJECT_ROOT"
cargo build --locked --release
BINARY="$(realpath "${CARGO_TARGET_DIR:-target}/release/streambot-touch")"
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

mkdir -p "$PACKAGE_ROOT/debian"
cat > "$PACKAGE_ROOT/debian/control" <<'CONTROL'
Source: streambot-touch
Section: utils
Priority: optional
Maintainer: Thomas Ludwig

Package: streambot-touch
Architecture: any
Description: Streambot Touch native kiosk
CONTROL
SHLIBS="$(cd "$PACKAGE_ROOT" && dpkg-shlibdeps -O -e"$BINARY" | sed 's/^shlibs:Depends=//')"
rm "$PACKAGE_ROOT/debian/control"
rmdir "$PACKAGE_ROOT/debian"
cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: streambot-touch
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: ${SHLIBS}, libwayland-client0, libxkbcommon0, libxkbcommon-x11-0, libx11-6, libxcursor1, libxi6, libxrandr2, fonts-dejavu-core, network-manager, bluez, pulseaudio-utils, procps, python3, iproute2
Suggests: matugen
Maintainer: Thomas Ludwig
Description: Streambot Touch native kiosk
 Touch interface for Streambot using Rust and Slint.
EOF


install -Dm755 \
    "$BINARY" \
    "$PACKAGE_ROOT/usr/bin/streambot-touch"

install -Dm755 \
    "$PROJECT_ROOT/helper/power_key_listener.py" \
    "$PACKAGE_ROOT/usr/lib/streambot-touch/power-key-listener"

install -Dm755 \
    "$PROJECT_ROOT/helper/generate_theme.sh" \
    "$PACKAGE_ROOT/usr/lib/streambot-touch/generate-theme"



install -Dm644 -t "$PACKAGE_ROOT/usr/share/streambot-touch/matugen" "$PROJECT_ROOT"/assets/matugen/*
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
