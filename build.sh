#!/usr/bin/env bash
set -euo pipefail

npm run tauri build

docker run --privileged --rm tonistiigi/binfmt --install arm64 >/dev/null 2>&1 || true

docker buildx rm tauri-multi >/dev/null 2>&1 || true

docker buildx create \
  --name tauri-multi \
  --driver docker-container \
  --driver-opt network=host \
  --use >/dev/null || docker buildx use tauri-multi

docker buildx inspect --bootstrap >/dev/null

docker buildx build \
  --platform linux/arm64 \
  -t tauri-arm64 \
  --load \
  .

docker run --rm \
  --platform linux/arm64 \
  --network host \
  -v "$PWD":/app \
  -v tauri_arm64_node_modules:/app/node_modules \
  -v tauri_arm64_dist:/app/dist \
  -v "$PWD/src-tauri/target:/app/target" \
  -w /app \
  -e CARGO_TARGET_DIR=/app/target \
  tauri-arm64 \
  bash -lc 'set -eux; rm -rf /app/dist/*; npm ci; npm run tauri build -- --target aarch64-unknown-linux-gnu --bundles deb'