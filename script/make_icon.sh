#!/usr/bin/env bash
# Regenerates Resources/Drift.icns from the design mark in render_icon.swift.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ICONSET="$(mktemp -d)/Drift.iconset"
swift "$ROOT_DIR/script/render_icon.swift" "$TMP_ICONSET"
iconutil -c icns "$TMP_ICONSET" -o "$ROOT_DIR/Resources/Drift.icns"
rm -rf "$TMP_ICONSET"
echo "wrote $ROOT_DIR/Resources/Drift.icns"
