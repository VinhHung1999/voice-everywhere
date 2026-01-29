#!/bin/bash
set -euo pipefail

APP_NAME="VoiceEverywhere"
BUILD_CONFIG="${1:-release}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/$BUILD_CONFIG"
EXECUTABLE="$BUILD_DIR/$APP_NAME"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"

echo "▶︎ Building $APP_NAME ($BUILD_CONFIG)…"
CLANG_MODULE_CACHE_PATH=${CLANG_MODULE_CACHE_PATH:-/tmp/module-cache} \
swift build --disable-sandbox -c "$BUILD_CONFIG"

echo "▶︎ Creating bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>VoiceEverywhere</string>
    <key>CFBundleDisplayName</key><string>VoiceEverywhere</string>
    <key>CFBundleIdentifier</key><string>com.local.voiceeverywhere</string>
    <key>CFBundleExecutable</key><string>VoiceEverywhere</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>VoiceEverywhere needs microphone access to transcribe speech.</string>
    <key>NSAppleEventsUsageDescription</key><string>VoiceEverywhere types recognized text into the active app.</string>
</dict>
</plist>
PLIST

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "✅ Done. Launch bundle:"
echo "open \"$APP_DIR\""
