#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sniplet"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
DMG_STAGING="$ROOT_DIR/dist/dmg-staging"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME-Installer.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle at $APP_PATH"
  echo "Run ./scripts/package_app.sh first."
  exit 1
fi

rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"

cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
xattr -cr "$DMG_STAGING"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo "Created DMG:"
echo "$DMG_PATH"
