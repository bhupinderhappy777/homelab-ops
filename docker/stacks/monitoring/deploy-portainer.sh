#!/usr/bin/env bash
# Portainer Git deploy/redeploy for this stack (default branch: main). Secrets live in Azure Key Vault; deploy .env via Ansible.
# After Portainer succeeds, merges Cloudflare Tunnel ingress from scripts/data/homelab-ingress.json (unless CLOUDFLARE_SKIP_INGRESS_SYNC=1).
# Usage: ./deploy-portainer.sh [redeploy]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="$(basename "$(cd "$(dirname "$0")" && pwd)")"
"$ROOT/scripts/portainer-git-stack.sh" "$STACK" "${1:-deploy}"
if [[ "${CLOUDFLARE_SKIP_INGRESS_SYNC:-}" != "1" ]]; then
  "$ROOT/scripts/cloudflared-sync-homelab-ingress.sh"
fi

