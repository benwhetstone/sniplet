#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/Sniplet.app"
TARGET_APP="/Applications/Sniplet.app"
INSTALLING_USER="${SUDO_USER:-$USER}"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Could not find Sniplet.app next to this installer."
  exit 1
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Installing Sniplet into /Applications..."
  echo "macOS may ask for your password once so it can replace the app cleanly."
  exec sudo "$0" "$@"
fi

pkill -f "$TARGET_APP/Contents/MacOS/Sniplet" 2>/dev/null || true
rm -rf "$TARGET_APP"
/usr/bin/ditto --noextattr --norsrc "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
xattr -cr "$TARGET_APP" 2>/dev/null || true

echo
echo "Sniplet is installed at:"
echo "$TARGET_APP"

if [[ -n "$INSTALLING_USER" ]]; then
  install_uid="$(id -u "$INSTALLING_USER" 2>/dev/null || true)"
  if [[ -n "$install_uid" ]]; then
    launchctl asuser "$install_uid" open "$TARGET_APP" 2>/dev/null || true
  else
    open "$TARGET_APP" 2>/dev/null || true
  fi
else
  open "$TARGET_APP" 2>/dev/null || true
fi

echo "If macOS still asks for confirmation on a Mac you trust, choose Open once and Sniplet should launch."
