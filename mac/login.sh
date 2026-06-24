#!/bin/bash
set -euo pipefail

echo ".........................................................."
echo "Tailscale Access:"

if command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale IPv4: $(tailscale ip -4 | head -n 1)"
  python3 - <<'PY'
import json
import subprocess

data = json.loads(subprocess.check_output(["tailscale", "status", "--json"], text=True))
dns_name = data.get("Self", {}).get("DNSName", "").rstrip(".")
print(f"MagicDNS: {dns_name}")
PY
  echo "VNC Address: <Tailscale-IP-or-MagicDNS>:5900"
else
  echo "Tailscale CLI not found."
fi

echo "Username: runneradmin"
echo "Password: P@ssw0rd!"
echo "VNC Password: runnerrdp"
