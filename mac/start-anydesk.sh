#!/bin/bash
set -euo pipefail

APP="/Applications/AnyDesk.app"
DMG="/tmp/AnyDesk.dmg"
MOUNT="/Volumes/AnyDesk"
PASSWORD="${ANYDESK_PASSWORD:?ANYDESK_PASSWORD is not set}"

echo "=== Downloading AnyDesk ==="

curl -fL \
  "https://download.anydesk.com/AnyDesk.dmg" \
  -o "$DMG"

echo "=== Mounting AnyDesk ==="

hdiutil attach "$DMG" \
  -nobrowse \
  -readonly \
  -mountpoint "$MOUNT"

echo "=== Installing AnyDesk ==="

if [ ! -d "$MOUNT/AnyDesk.app" ]; then
  echo "ERROR: AnyDesk.app was not found in the downloaded DMG."
  hdiutil detach "$MOUNT" || true
  exit 1
fi

sudo rm -rf "$APP"
sudo cp -R "$MOUNT/AnyDesk.app" "$APP"

hdiutil detach "$MOUNT" || true
rm -f "$DMG"

echo "=== Starting AnyDesk ==="

sudo open -a "$APP"

sleep 10

ANYDESK="$APP/Contents/MacOS/AnyDesk"

if [ ! -x "$ANYDESK" ]; then
  echo "ERROR: AnyDesk executable not found."
  exit 1
fi

echo "=== AnyDesk Version ==="
"$ANYDESK" --version || true

echo "=== AnyDesk ID ==="

ANYDESK_ID="$("$ANYDESK" --get-id 2>/dev/null | tr -d '\r' | tail -n 1)"

if [ -z "$ANYDESK_ID" ]; then
  echo "ERROR: Could not obtain AnyDesk ID."
  exit 1
fi

echo "AnyDesk ID: $ANYDESK_ID"

echo "=== Setting Unattended Access Password ==="

printf '%s\n' "$PASSWORD" | sudo "$ANYDESK" --set-password

echo "Unattended Access password configured."

echo "=== AnyDesk Status ==="

"$ANYDESK" --get-status || true

echo "========================================"
echo "           ANYDESK CONNECTION"
echo "========================================"
echo "AnyDesk ID: $ANYDESK_ID"
echo "Password: configured through GitHub Secret"
echo "========================================"

echo "AnyDesk is running."
