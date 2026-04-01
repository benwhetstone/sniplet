#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/apple/Products/Release"
APP_NAME="Sniplet"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_TEMPLATE="$ROOT_DIR/packaging/Info.plist"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICON_PATH="$ROOT_DIR/packaging/Sniplet.icns"

mkdir -p "$ROOT_DIR/dist"

swift build -c release --product "$APP_NAME"
BUILD_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
cp "$PLIST_TEMPLATE" "$PLIST_PATH"
if [[ -f "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$RESOURCES_DIR/$APP_NAME.icns"
fi
chmod +x "$MACOS_DIR/$APP_NAME"

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "Packaged app:"
echo "$APP_DIR"
