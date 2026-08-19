```bash
#!/bin/bash
set -euo pipefail

ANYDESK_VERSION="9.7.3"
DMG="/tmp/AnyDesk.dmg"
MOUNT="/Volumes/AnyDesk"
APP="/Applications/AnyDesk.app"
PASSWORD="${ANYDESK_PASSWORD:-runnerrdp}"

echo "=== Installing AnyDesk ==="

# Download official AnyDesk macOS Intel build
curl -L --fail --silent --show-error \
  "https://download.anydesk.com/macos/AnyDesk.dmg" \
  -o "$DMG"

# Mount installer
hdiutil attach "$DMG" \
  -nobrowse \
  -readonly \
  -mountpoint "$MOUNT"

# Install application
if [ -d "$MOUNT/AnyDesk.app" ]; then
    sudo rm -rf "$APP"
    sudo cp -R "$MOUNT/AnyDesk.app" "$APP"
else
    echo "AnyDesk.app not found in DMG"
    hdiutil detach "$MOUNT" || true
    exit 1
fi

# Unmount
hdiutil detach "$MOUNT"

chmod +x "$APP/Contents/MacOS/AnyDesk"

echo "=== Starting AnyDesk ==="

open -a "$APP"

sleep 8

echo "=== AnyDesk Version ==="
"$APP/Contents/MacOS/AnyDesk" --version || true

echo "=== AnyDesk ID ==="
ANYDESK_ID=$("$APP/Contents/MacOS/AnyDesk" --get-id | tail -n 1)

echo "AnyDesk ID: $ANYDESK_ID"

echo "=== Configure Unattended Access ==="

printf '%s\n' "$PASSWORD" | \
  sudo "$APP/Contents/MacOS/AnyDesk" --set-password

echo "Unattended Access password configured."

echo "=== AnyDesk Status ==="
"$APP/Contents/MacOS/AnyDesk" --get-status || true

echo "=========================================="
echo "ANYDESK ID: $ANYDESK_ID"
echo "ANYDESK PASSWORD: $PASSWORD"
echo "=========================================="

echo "Keep this GitHub Actions job running."
```
