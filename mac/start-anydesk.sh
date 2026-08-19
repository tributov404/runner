#!/bin/bash
set -euo pipefail

APP="/Applications/AnyDesk.app"
DMG="$(pwd)/mac/AnyDesk.dmg"
MOUNT="/Volumes/AnyDesk"

PASSWORD="${ANYDESK_PASSWORD:?ANYDESK_PASSWORD is not set}"

echo "=== Checking AnyDesk installer ==="

if [ ! -f "$DMG" ]; then
    echo "ERROR: $DMG not found"
    exit 1
fi

echo "=== Mounting AnyDesk DMG ==="

hdiutil attach "$DMG" \
    -nobrowse \
    -readonly \
    -mountpoint "$MOUNT"

echo "=== Installing AnyDesk ==="

if [ ! -d "$MOUNT/AnyDesk.app" ]; then
    echo "ERROR: AnyDesk.app not found inside DMG"
    hdiutil detach "$MOUNT" || true
    exit 1
fi

sudo rm -rf "$APP"
sudo cp -R "$MOUNT/AnyDesk.app" "$APP"

hdiutil detach "$MOUNT" || true

ANYDESK="$APP/Contents/MacOS/AnyDesk"

chmod +x "$ANYDESK"

echo "=== Installing AnyDesk Service ==="

sudo "$ANYDESK" --install-service || true

sleep 5

echo "=== Starting AnyDesk ==="

open -a "$APP"

sleep 15

echo "=== Checking AnyDesk process ==="

pgrep -fl AnyDesk || true

echo "=== Version ==="

"$ANYDESK" --version || true

echo "=== Getting AnyDesk ID ==="

ID=""

for i in {1..10}; do
    ID="$("$ANYDESK" --get-id 2>/dev/null | tail -n 1 | tr -d '\r' || true)"

    if [ -n "$ID" ]; then
        break
    fi

    echo "Waiting for ID..."
    sleep 5
done

if [ -z "$ID" ]; then
    echo "ERROR: AnyDesk ID was not returned"
    exit 1
fi

echo "AnyDesk ID: $ID"

echo "=== Setting unattended access ==="

echo "$PASSWORD" | sudo "$ANYDESK" --set-password || {
    echo "Retrying after restarting service..."

    sudo launchctl kickstart -k system/com.anydesk.anydesk.service || true

    sleep 10

    echo "$PASSWORD" | sudo "$ANYDESK" --set-password
}

echo "Unattended Access password configured."

echo "=== Status ==="

"$ANYDESK" --get-status || true

echo "======================================"
echo "ANYDESK ID: $ID"
echo "======================================"
