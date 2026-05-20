#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/SteamIdleMac.app"
if [ ! -d "$APP" ]; then
    echo "Building app first..."
    bash "$ROOT/scripts/build-app.sh"
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
OUT_DIR="$ROOT/build"
DMG_PATH="$OUT_DIR/SteamIdleMac-${VERSION}.dmg"
mkdir -p "$OUT_DIR"
rm -f "$DMG_PATH"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "Installing create-dmg..."
    if command -v brew >/dev/null 2>&1; then
        brew install create-dmg
    else
        echo "create-dmg not found. Install from: https://github.com/create-dmg/create-dmg"
        exit 1
    fi
fi

BG_PNG="$ROOT/scripts/dmg-background.png"
if [ ! -f "$BG_PNG" ]; then
    swift "$ROOT/scripts/generate-dmg-background.swift" "$BG_PNG" 2>/dev/null || true
fi

EXTRA=()
[ -f "$BG_PNG" ] && EXTRA+=(--background "$BG_PNG")

create-dmg \
    --volname "Steam Idle Mac ${VERSION}" \
    --window-pos 200 120 \
    --window-size 640 400 \
    --icon-size 128 \
    --icon "SteamIdleMac.app" 160 200 \
    --app-drop-link 480 200 \
    --hide-extension "SteamIdleMac.app" \
    "${EXTRA[@]}" \
    "$DMG_PATH" \
    "$APP"

echo "Built: $DMG_PATH"
