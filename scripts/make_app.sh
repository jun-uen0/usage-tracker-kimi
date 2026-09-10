#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="KimiUsageTracker"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>KimiUsageTracker</string>
    <key>CFBundleDisplayName</key>
    <string>Kimi Usage Tracker</string>
    <key>CFBundleIdentifier</key>
    <string>dev.junueno.usage-tracker-kimi</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>KimiUsageTracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"
