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
TUTORIAL_PATH="$ROOT_DIR/packaging/Tutorial.html"

mkdir -p "$ROOT_DIR/dist"

swift build -c release --product "$APP_NAME"
BUILD_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/ditto --noextattr --norsrc "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
/usr/bin/ditto --noextattr --norsrc "$PLIST_TEMPLATE" "$PLIST_PATH"
if [[ -f "$ICON_PATH" ]]; then
  /usr/bin/ditto --noextattr --norsrc "$ICON_PATH" "$RESOURCES_DIR/$APP_NAME.icns"
fi
if [[ -f "$TUTORIAL_PATH" ]]; then
  /usr/bin/ditto --noextattr --norsrc "$TUTORIAL_PATH" "$RESOURCES_DIR/Tutorial.html"
fi
chmod +x "$MACOS_DIR/$APP_NAME"

find "$APP_DIR" -exec xattr -c {} + 2>/dev/null || true
find "$APP_DIR" -exec xattr -d com.apple.provenance {} + 2>/dev/null || true
find "$APP_DIR" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
find "$APP_DIR" -exec xattr -d "com.apple.fileprovider.fpfs#P" {} + 2>/dev/null || true
xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

echo "Packaged app:"
echo "$APP_DIR"
