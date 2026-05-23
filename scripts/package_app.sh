#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/apple/Products/Release"
APP_NAME="Sniplet"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
PLIST_TEMPLATE="$ROOT_DIR/packaging/Info.plist"
ICON_PATH="$ROOT_DIR/packaging/Sniplet.icns"
TUTORIAL_PATH="$ROOT_DIR/packaging/Tutorial.html"
SIGNING_IDENTITY="${SNIPLET_SIGNING_IDENTITY:-"-"}"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/sniplet-app.XXXXXX")"
TEMP_APP_DIR="$TEMP_ROOT/$APP_NAME.app"
TEMP_CONTENTS_DIR="$TEMP_APP_DIR/Contents"
TEMP_MACOS_DIR="$TEMP_CONTENTS_DIR/MacOS"
TEMP_RESOURCES_DIR="$TEMP_CONTENTS_DIR/Resources"
TEMP_PLIST_PATH="$TEMP_CONTENTS_DIR/Info.plist"

cleanup() {
  rm -rf "$TEMP_ROOT"
}

trap cleanup EXIT

mkdir -p "$ROOT_DIR/dist"

swift build -c release --product "$APP_NAME"
BUILD_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$TEMP_MACOS_DIR" "$TEMP_RESOURCES_DIR"

/usr/bin/ditto --noextattr --norsrc "$EXECUTABLE" "$TEMP_MACOS_DIR/$APP_NAME"
/usr/bin/ditto --noextattr --norsrc "$PLIST_TEMPLATE" "$TEMP_PLIST_PATH"
if [[ -f "$ICON_PATH" ]]; then
  /usr/bin/ditto --noextattr --norsrc "$ICON_PATH" "$TEMP_RESOURCES_DIR/$APP_NAME.icns"
fi
if [[ -f "$TUTORIAL_PATH" ]]; then
  /usr/bin/ditto --noextattr --norsrc "$TUTORIAL_PATH" "$TEMP_RESOURCES_DIR/Tutorial.html"
fi
chmod +x "$TEMP_MACOS_DIR/$APP_NAME"

find "$TEMP_APP_DIR" -exec xattr -c {} + 2>/dev/null || true
find "$TEMP_APP_DIR" -exec xattr -d com.apple.provenance {} + 2>/dev/null || true
find "$TEMP_APP_DIR" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
find "$TEMP_APP_DIR" -exec xattr -d "com.apple.fileprovider.fpfs#P" {} + 2>/dev/null || true
xattr -cr "$TEMP_APP_DIR" 2>/dev/null || true
codesign --force --deep --sign "$SIGNING_IDENTITY" "$TEMP_APP_DIR"
codesign --verify --deep --strict --verbose=2 "$TEMP_APP_DIR"

/usr/bin/ditto --noextattr --norsrc "$TEMP_APP_DIR" "$APP_DIR"
xattr -d com.apple.provenance "$APP_DIR" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d "com.apple.fileprovider.fpfs#P" "$APP_DIR" 2>/dev/null || true
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "Packaged app:"
echo "$APP_DIR"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Signing mode: ad hoc"
  echo "Note: macOS permissions like Screen Recording may reset between updates until you package with a stable signing identity."
else
  echo "Signing identity:"
  echo "$SIGNING_IDENTITY"
fi
