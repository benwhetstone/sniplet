#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/Sniplet.app"
TARGET_APP="/Applications/Sniplet.app"
TARGET_BINARY="$TARGET_APP/Contents/MacOS/Sniplet"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Could not find Sniplet.app next to this installer."
  exit 1
fi

echo "Installing Sniplet into /Applications..."
echo "macOS should ask for your password once so it can replace the app cleanly."

privileged_command=$(cat <<EOF
pkill -f ${(q)TARGET_BINARY} 2>/dev/null || true
rm -rf ${(q)TARGET_APP}
/usr/bin/ditto --noextattr --norsrc ${(q)SOURCE_APP} ${(q)TARGET_APP}
xattr -dr com.apple.quarantine ${(q)TARGET_APP} 2>/dev/null || true
xattr -cr ${(q)TARGET_APP} 2>/dev/null || true
spctl --add --label Sniplet ${(q)TARGET_APP} 2>/dev/null || true
spctl --enable --label Sniplet 2>/dev/null || true
EOF
)

if ! /usr/bin/osascript <<'APPLESCRIPT' "$privileged_command"
on run argv
    try
        do shell script (item 1 of argv) with administrator privileges
    on error errMsg number errNum
        if errNum is -128 then
            error "Installation canceled."
        end if
        error errMsg
    end try
end run
APPLESCRIPT
then
  echo "Installation was canceled or could not finish."
  exit 1
fi

echo
echo "Sniplet is installed at:"
echo "$TARGET_APP"

open "$TARGET_APP" 2>/dev/null || true

echo "Sniplet was also approved for this Mac so Gatekeeper is less likely to block the first launch."
