#!/bin/bash
set -euo pipefail

sudo mdutil -i off -a || true

USERNAME="runneradmin"
PASSWORD='P@ssw0rd!'

if ! id "$USERNAME" >/dev/null 2>&1; then
    sudo dscl . -create "/Users/$USERNAME"
    sudo dscl . -create "/Users/$USERNAME" UserShell /bin/bash
    sudo dscl . -create "/Users/$USERNAME" RealName "Runner Admin"
    sudo dscl . -create "/Users/$USERNAME" UniqueID 1001
    sudo dscl . -create "/Users/$USERNAME" PrimaryGroupID 80
    sudo dscl . -create "/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
    sudo dscl . -passwd "/Users/$USERNAME" "$PASSWORD"
    sudo dscl . -append /Groups/admin GroupMembership "$USERNAME"
fi

sudo createhomedir -c -u "$USERNAME" >/dev/null 2>&1 || true
sudo chown -R "$USERNAME":staff "/Users/$USERNAME" || true

ARD="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"

sudo "$ARD" -activate
sudo "$ARD" -configure -allowAccessFor -allUsers -privs -all
sudo "$ARD" -configure -clientopts -setvnclegacy -vnclegacy yes

echo "runnerrdp" | perl -we '
BEGIN {
    @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA";
}
$_ = <>;
chomp;
s/^(.{8}).*/$1/;
@p = unpack "C*", $_;
foreach (@k) {
    printf "%02X", $_ ^ (shift @p || 0)
};
print "\n";
' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt >/dev/null

sudo "$ARD" -restart -agent -console

echo "=== Remote Management ==="
sudo "$ARD" -status || true

echo "=== Console user ==="
stat -f '%Su' /dev/console || true

echo "=== Display ==="
system_profiler SPDisplaysDataType | head -n 30 || true

echo "VNC is enabled on port 5900."
