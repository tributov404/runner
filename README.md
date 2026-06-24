# mac-vnc-tailscale

GitHub Actions macOS runner setup with:

- Tailscale connectivity
- VNC access on port `5900`
- `tmate` fallback shell access

## Required Secret

Add this repository secret before running the workflow:

- `TAILSCALE_AUTHKEY`

## Run

Start the workflow from the `Actions` tab, then open the `Print VNC Details` step logs to get:

- Tailscale IPv4
- MagicDNS hostname
- GUI/VNC credentials
