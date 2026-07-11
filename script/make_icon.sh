#!/usr/bin/env bash
# Regenerates Resources/Swarm.icns from the design mark in render_icon.swift.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ICONSET="$(mktemp -d)/Swarm.iconset"
swift "$ROOT_DIR/script/render_icon.swift" "$TMP_ICONSET"
iconutil -c icns "$TMP_ICONSET" -o "$ROOT_DIR/Resources/Swarm.icns"
rm -rf "$TMP_ICONSET"
echo "wrote $ROOT_DIR/Resources/Swarm.icns"
