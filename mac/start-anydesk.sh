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
sudo xattr -rd com.apple.quarantine "$APP" 2>/dev/null || true

# Регистрация privileged helper (нужен для set-password и системных функций)
echo "=== Registering AnyDesk helper ==="
sudo launchctl unload /Library/LaunchDaemons/com.philandro.anydesk.Helper.plist 2>/dev/null || true
sudo launchctl load /Library/LaunchDaemons/com.philandro.anydesk.Helper.plist 2>/dev/null || true
sudo "$APP/Contents/Helpers/AnyDesk Helper.app/Contents/MacOS/AnyDesk Helper" --register-helper 2>/dev/null || true

echo "=== Killing previous AnyDesk ==="
sudo pkill -9 -f AnyDesk 2>/dev/null || true
sleep 3

echo "=== Starting AnyDesk Local Service (as USER, not root) ==="
# ВАЖНО: без sudo. Иначе сервис не сможет подключиться к user-session.
"$ANYDESK" --local-service >/tmp/anydesk-service.log 2>&1 &
SERVICE_PID=$!
echo "Service PID: $SERVICE_PID"

# Ждём пока сервис реально поднимется
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
"$ANYDESK" --control >/tmp/anydesk-control.log 2>&1 &
CONTROL_PID=$!
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

# ─────────────────────────────────────────────────────────────────────
# ФИКС: set-password ОБЯЗАТЕЛЬНО под sudo, иначе ловим
# "Setting the password requires administrator privileges".
# Дополнительно: дёргаем без shell-pipe (через printf | sudo -S),
# чтобы sudo не подвис на своём prompt и не съел пароль.
# ─────────────────────────────────────────────────────────────────────
echo "=== Setting unattended access password (sudo) ==="
PASSWORD_SET=false
for i in {1..8}; do
    # sudo без -S: надеемся на NOPASSWD / уже закэшированную сессию.
    # Если у тебя интерактивный sudo — замени на: sudo -S "$ANYDESK" --set-password <<< "$PASSWORD"
    if printf '%s' "$PASSWORD" | sudo "$ANYDESK" --set-password; then
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

# Доп. проверка, что пароль реально встал (некоторые версии не падают,
# а молча проглатывают неудачу)
echo "=== Verifying unattended password is set ==="
if sudo "$ANYDESK" --get-status 2>/dev/null | grep -qi "unattended.*on\|password.*set"; then
    echo "Unattended access: OK"
else
    echo "WARN: Could not verify unattended status, but --set-password returned 0"
    sudo "$ANYDESK" --get-status || true
fi

echo "=== Final Status ==="
"$ANYDESK" --get-status || true
echo "======================================"
echo "ANYDESK ID: $ID"
echo "======================================"
