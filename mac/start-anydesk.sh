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

sudo chmod +x "$ANYDESK"


echo "=== Installing AnyDesk Service ==="

# создаём сервис AnyDesk
sudo "$ANYDESK" --install-service 2>&1 || true


echo "=== Starting AnyDesk ==="

open "$APP"

sleep 20


echo "=== Processes ==="

pgrep -fl AnyDesk || true


echo "=== Version ==="

"$ANYDESK" --version || true


echo "=== Restarting AnyDesk Service ==="

sudo launchctl kickstart -k system/com.anydesk.anydesk.service 2>/dev/null || true

sleep 15


echo "=== Waiting for AnyDesk service ==="

for i in {1..12}; do

    STATUS="$("$ANYDESK" --get-status 2>/dev/null || true)"

    echo "Status: $STATUS"

    if [ -n "$STATUS" ]; then
        break
    fi

    sleep 5

done


echo "=== Getting AnyDesk ID ==="

ID=""

for i in {1..15}; do

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


for i in {1..5}; do

    if echo "$PASSWORD" | sudo "$ANYDESK" --set-password; then
        echo "Password configured"
        break
    fi

    echo "Password setup failed, retry $i..."

    sudo launchctl kickstart -k system/com.anydesk.anydesk.service 2>/dev/null || true

    sleep 10

done


echo "=== Final Status ==="

"$ANYDESK" --get-status || true


echo "======================================"
echo "ANYDESK ID: $ID"
echo "======================================"
