#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[1/4] Building release binary..."
swift build -c release

BIN_PATH="$SCRIPT_DIR/.build/out/Products/Release/CameraShutterCount"
if [ ! -f "$BIN_PATH" ]; then
    BIN_PATH=$(find "$SCRIPT_DIR/.build" -type f -perm +111 -name "CameraShutterCount" | grep -i "release" | head -n 1)
fi

if [ -z "$BIN_PATH" ] || [ ! -f "$BIN_PATH" ]; then
    echo "Error: Release binary not found."
    exit 1
fi

APP_DIR="$SCRIPT_DIR/CameraShutterCount.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "[2/4] Assembling application bundle: $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BIN_PATH" "$MACOS_DIR/CameraShutterCount"
chmod +x "$MACOS_DIR/CameraShutterCount"

# Copy AppIcon if available
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "[3/4] Generating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CameraShutterCount</string>
    <key>CFBundleIdentifier</key>
    <string>com.boywei.camerashuttercount</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Camera Shutter Count</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026. All rights reserved.</string>
    <key>NSCameraUsageDescription</key>
    <string>Access is required to read shutter actuations via USB PTP.</string>
</dict>
</plist>
EOF

echo "[4/4] Finalizing application bundle..."
touch "$APP_DIR"

echo "Build complete: $APP_DIR"
