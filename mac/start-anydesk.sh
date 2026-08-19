#!/bin/bash
set -euo pipefail

APP="/Applications/AnyDesk.app"
DMG="$(pwd)/mac/AnyDesk.dmg"
MOUNT="/Volumes/AnyDesk"

: "${ANYDESK_PASSWORD:?ANYDESK_PASSWORD is not set}"
PASSWORD="$ANYDESK_PASSWORD"

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
sudo xattr -rd com.apple.quarantine "$APP" 2>/dev/null || true

# Регистрация хелпера
echo "=== Registering AnyDesk helper ==="
sudo launchctl unload /Library/LaunchDaemons/com.philandro.anydesk.Helper.plist 2>/dev/null || true
sudo "$ANYDESK" --register-helper || true
sudo launchctl load /Library/LaunchDaemons/com.philandro.anydesk.Helper.plist 2>/dev/null || true

# Убиваем старые процессы AnyDesk, но НЕ свой shell и не родителя
echo "=== Killing previous AnyDesk ==="
sudo pkill -9 -x "AnyDesk" 2>/dev/null || true
sleep 3

# Локальный сервис — обязательно от пользователя, не от root
echo "=== Starting AnyDesk Local Service (as USER) ==="
nohup "$ANYDESK" --local-service >/tmp/anydesk-service.log 2>&1 &
SERVICE_PID=$!
disown "$SERVICE_PID" 2>/dev/null || true
echo "Service PID: $SERVICE_PID"

echo "=== Waiting for service to be ready ==="
SERVICE_READY=false
for i in {1..40}; do
    STATUS="$("$ANYDESK" --get-status 2>/dev/null || true)"
    if echo "$STATUS" | grep -qi "connected\|online\|ready"; then
        echo "Service is up! ($STATUS)"
        SERVICE_READY=true
        break
    fi
    echo "  ...waiting ($i) status=$STATUS"
    sleep 2
done

if [ "$SERVICE_READY" != "true" ]; then
    echo "ERROR: AnyDesk service did not start in time"
    echo "=== Service log ==="
    cat /tmp/anydesk-service.log || true
    exit 1
fi

echo "=== Starting AnyDesk Control (as USER) ==="
nohup "$ANYDESK" --control >/tmp/anydesk-control.log 2>&1 &
CONTROL_PID=$!
disown "$CONTROL_PID" 2>/dev/null || true
echo "Control PID: $CONTROL_PID"
sleep 8

echo "=== Starting AnyDesk GUI ==="
open "$APP"
sleep 8

echo "=== AnyDesk processes ==="
pgrep -fl AnyDesk || true

echo "=== Version ==="
"$ANYDESK" --version || true

echo "=== Getting AnyDesk ID ==="
ID=""
for i in {1..30}; do
    ID="$("$ANYDESK" --get-id 2>/dev/null | tail -n 1 | tr -d '\r' || true)"
    if [ -n "$ID" ] && [ "$ID" != "SERVICE_NOT_RUNNING" ]; then
        break
    fi
    echo "  Waiting for ID... ($i)"
    sleep 3
done

if [ -z "$ID" ] || [ "$ID" = "SERVICE_NOT_RUNNING" ]; then
    echo "ERROR: AnyDesk ID not returned"
    echo "=== Service log ==="; cat /tmp/anydesk-service.log || true
    echo "=== Control log ==="; cat /tmp/anydesk-control.log || true
    exit 1
fi

echo "AnyDesk ID: $ID"
"$ANYDESK" --get-status || true

# Пароль через printf+pipe (herestring + sudo — ненадёжно)
echo "=== Setting unattended access password (sudo) ==="
PASSWORD_SET=false
for i in {1..8}; do
    if printf '%s\n' "$PASSWORD" | sudo "$ANYDESK" --set-password 2>/dev/null; then
        PASSWORD_SET=true
        echo "Unattended password configured."
        break
    fi
    echo "Password setup failed, retry $i..."
    sleep 10
done

if [ "$PASSWORD_SET" != "true" ]; then
    echo "ERROR: Could not configure unattended access"
    echo "=== Service log ==="; cat /tmp/anydesk-service.log || true
    echo "=== Control log ==="; cat /tmp/anydesk-control.log || true
    exit 1
fi

echo "=== Final Status ==="
"$ANYDESK" --get-status || true
echo "======================================"
echo "ANYDESK ID: $ID"
echo "======================================"
