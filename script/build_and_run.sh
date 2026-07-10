#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
APP_NAME="Drift"
BUNDLE_ID="ru.iliebanda.Drift"
APP_VERSION="1.0"
APP_BUILD="1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
APP_RESOURCES="$APP_CONTENTS/Resources"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
cd "$ROOT_DIR"
swift build --arch arm64
BUILD_BINARY="$(swift build --show-bin-path --arch arm64)/$APP_NAME"
rm -rf "$APP_BUNDLE"; mkdir -p "$APP_MACOS" "$APP_RESOURCES"; cp "$BUILD_BINARY" "$APP_BINARY"; cp "$ROOT_DIR/Resources/Drift.icns" "$APP_RESOURCES/Drift.icns"; chmod +x "$APP_BINARY"
# Localizations must live in the .app so Bundle.main resolves them; SwiftPM's Bundle.module is not copied here.
for lproj in "$ROOT_DIR"/Resources/*.lproj; do
  [ -d "$lproj" ] || continue
  dest="$APP_RESOURCES/$(basename "$lproj")"
  mkdir -p "$dest"
  for file in "$lproj"/*.strings; do [ -e "$file" ] && plutil -convert binary1 "$file" -o "$dest/$(basename "$file")"; done
  for file in "$lproj"/*.stringsdict; do [ -e "$file" ] && plutil -convert binary1 "$file" -o "$dest/$(basename "$file")"; done
done
cat > "$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>$APP_NAME</string><key>CFBundleIdentifier</key><string>$BUNDLE_ID</string><key>CFBundleName</key><string>$APP_NAME</string><key>CFBundleDisplayName</key><string>$APP_NAME</string><key>CFBundleShortVersionString</key><string>$APP_VERSION</string><key>CFBundleVersion</key><string>$APP_BUILD</string><key>NSHumanReadableCopyright</key><string>© 2026 Ilia Banda</string><key>CFBundleIconFile</key><string>Drift.icns</string><key>LSApplicationCategoryType</key><string>public.app-category.utilities</string><key>ITSAppUsesNonExemptEncryption</key><false/><key>NSLocalNetworkUsageDescription</key><string>Drift connects to Transmission servers on your local network.</string><key>NSBonjourServices</key><array><string>_transmission._tcp</string></array><key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPrincipalClass</key><string>NSApplication</string><key>CFBundleDevelopmentRegion</key><string>en</string><key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array><key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>$BUNDLE_ID.magnet</string><key>CFBundleURLSchemes</key><array><string>magnet</string></array><key>CFBundleTypeRole</key><string>Viewer</string></dict></array><key>UTImportedTypeDeclarations</key><array><dict><key>UTTypeIdentifier</key><string>org.bittorrent.torrent</string><key>UTTypeConformsTo</key><array><string>public.data</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>torrent</string></array></dict></dict></array><key>CFBundleDocumentTypes</key><array><dict><key>CFBundleTypeName</key><string>BitTorrent Metainfo File</string><key>CFBundleTypeRole</key><string>Viewer</string><key>LSHandlerRank</key><string>Alternate</string><key>LSItemContentTypes</key><array><string>org.bittorrent.torrent</string></array></dict></array></dict></plist>
PLIST
codesign --force --deep --sign - --identifier "$BUNDLE_ID" --options runtime --entitlements "$ROOT_DIR/Drift.entitlements" "$APP_BUNDLE"
case "$MODE" in run) /usr/bin/open -n "$APP_BUNDLE" ;; --verify|verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;; *) echo "usage: $0 [run|--verify]" >&2; exit 2 ;; esac
