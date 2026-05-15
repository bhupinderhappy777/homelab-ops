#!/usr/bin/env bash
# Portainer Git deploy/redeploy for this stack (default branch: main). Secrets live in Azure Key Vault; deploy .env via Ansible.
# Usage: ./deploy-portainer.sh [redeploy]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="$(basename "$(cd "$(dirname "$0")" && pwd)")"
exec "$ROOT/scripts/portainer-git-stack.sh" "$STACK" "${1:-deploy}"
