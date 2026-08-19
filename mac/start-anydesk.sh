#!/bin/bash
set -euo pipefail

APP="/Applications/AnyDesk.app"
DMG="$(pwd)/mac/AnyDesk.dmg"
MOUNT="/Volumes/AnyDesk"

PASSWORD="${ANYDESK_PASSWORD:?ANYDESK_PASSWORD is not set}"

cleanup() {
    hdiutil detach "$MOUNT" 2>/dev/null || true
}

trap cleanup EXIT


echo "=== Checking AnyDesk installer ==="

if [ ! -f "$DMG" ]; then
    echo "ERROR: $DMG not found"
    exit 1
fi


echo "=== Preparing mount ==="

hdiutil detach "$MOUNT" 2>/dev/null || true


echo "=== Mounting AnyDesk DMG ==="

hdiutil attach "$DMG" \
    -nobrowse \
    -readonly \
    -mountpoint "$MOUNT"


echo "=== Installing AnyDesk ==="

if [ ! -d "$MOUNT/AnyDesk.app" ]; then
    echo "ERROR: AnyDesk.app not found inside DMG"
    exit 1
fi


sudo rm -rf "$APP"
sudo cp -R "$MOUNT/AnyDesk.app" "$APP"


ANYDESK="$APP/Contents/MacOS/AnyDesk"

sudo chmod +x "$ANYDESK"


echo "=== Starting AnyDesk Local Service ==="

sudo pkill -f "AnyDesk --local-service" 2>/dev/null || true

sudo "$ANYDESK" --local-service \
    >/tmp/anydesk-service.log 2>&1 &


sleep 20


echo "=== Starting AnyDesk Control ==="

sudo pkill -f "AnyDesk --control" 2>/dev/null || true

sudo "$ANYDESK" --control \
    >/tmp/anydesk-control.log 2>&1 &


sleep 20


echo "=== Starting AnyDesk GUI ==="

open "$APP"

sleep 20


echo "=== Checking AnyDesk processes ==="

pgrep -fl AnyDesk || true


echo "=== Version ==="

"$ANYDESK" --version || true


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

    echo "=== Service log ==="
    cat /tmp/anydesk-service.log || true

    echo "=== Control log ==="
    cat /tmp/anydesk-control.log || true

    exit 1
fi


echo "AnyDesk ID: $ID"


echo "=== Checking status ==="

"$ANYDESK" --get-status || true


echo "=== Setting unattended access ==="


PASSWORD_SET=false

for i in {1..8}; do

    if echo "$PASSWORD" | sudo "$ANYDESK" --set-password; then
        PASSWORD_SET=true
        echo "Unattended Access password configured."
        break
    fi

    echo "Password setup failed, retry $i..."

    sleep 15

done


if [ "$PASSWORD_SET" != true ]; then

    echo "ERROR: Could not configure unattended access"

    echo "=== Service log ==="
    cat /tmp/anydesk-service.log || true

    echo "=== Control log ==="
    cat /tmp/anydesk-control.log || true

    exit 1

fi


echo "=== Final Status ==="

"$ANYDESK" --get-status || true


echo "======================================"
echo "ANYDESK ID: $ID"
echo "======================================"
