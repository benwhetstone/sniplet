#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sniplet"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME-Installer.dmg"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/sniplet-dmg.XXXXXX")"
DMG_STAGING="$TEMP_ROOT/dmg-staging"

cleanup() {
  rm -rf "$TEMP_ROOT"
}

trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle at $APP_PATH"
  echo "Run ./scripts/package_app.sh first."
  exit 1
fi

rm -rf "$DMG_PATH"
mkdir -p "$DMG_STAGING"

/usr/bin/ditto --noextattr --norsrc "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
find "$DMG_STAGING" -exec xattr -c {} + 2>/dev/null || true
find "$DMG_STAGING" -exec xattr -d com.apple.provenance {} + 2>/dev/null || true
find "$DMG_STAGING" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
find "$DMG_STAGING" -exec xattr -d "com.apple.fileprovider.fpfs#P" {} + 2>/dev/null || true
xattr -cr "$DMG_STAGING" 2>/dev/null || true

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created DMG:"
echo "$DMG_PATH"
