#!/usr/bin/env bash
# Read KEY=value pairs from a .env file and push matching secrets to Azure Key Vault.
#
# Usage (from repo root):
#   export AZURE_KEY_VAULT_NAME='your-vault-name'
#   ./ansible/scripts/seed_keyvault_hardcoded.example.sh [path/to/.env]
#
# Default .env path: docker/.env (repo root). Override with first argument or SEED_ENV_FILE.
#
# Prerequisites:
#   az login
#   Secret Set permission on the vault (e.g. in vault-rg).
#
# Only keys listed in the map below are uploaded. Optional keys (OCI, restic, Tailscale)
# can be added to the same .env — see docker/.env.example tail section.
#
# Values with leading/trailing double quotes are unquoted. Lines starting with # are ignored.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -z "${AZURE_KEY_VAULT_NAME:-}" ]]; then
  echo "error: export AZURE_KEY_VAULT_NAME to your vault name" >&2
  exit 1
fi

ENV_FILE="${1:-${SEED_ENV_FILE:-$REPO_ROOT/docker/.env}}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: .env file not found: $ENV_FILE" >&2
  echo "  Create docker/.env from docker/.env.example or pass path: $0 /path/to/.env" >&2
  exit 1
fi

# shellcheck disable=SC2034
declare -A ENV_TO_KV=(
  [CLOUDFLARE_TUNNEL_TOKEN]=cloudflare-tunnel-token
  [COUCHDB_USER]=couchdb-user
  [COUCHDB_PASSWORD]=couchdb-password
  [DOCUSEAL_POSTGRES_PASSWORD]=docuseal-postgres-password
  [FIREFLY_APP_KEY]=firefly-app-key
  [FIREFLY_DB_PASSWORD]=firefly-db-password
  [FIREFLY_CRON_TOKEN]=firefly-cron-token
  [IMMICH_DB_PASSWORD]=immich-db-password
  [MONICA_DB_PASSWORD]=monica-db-password
  [MONICA_APP_KEY]=monica-app-key
  [GRAFANA_PASSWORD]=grafana-password
  [OPENWEBUI_SECRET_KEY]=openwebui-secret-key
  [PAPERLESS_DB_USER]=paperless-db-user
  [PAPERLESS_DB_PASSWORD]=paperless-db-password
  [PIHOLE_PASSWORD]=pihole-password
  [RESTIC_PASSWORD]=restic-password
  [OCI_S3_ACCESS_KEY_ID]=oci-s3-access-key-id
  [OCI_S3_SECRET_ACCESS_KEY]=oci-s3-secret-access-key
  [OCI_S3_BUCKET]=oci-s3-bucket
  [OCI_S3_ENDPOINT]=oci-s3-endpoint
  [TAILSCALE_AUTH_KEY]=tailscale-auth-key
)

declare -A VALS=()

trim() {
  local s=$1
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Strip matching double quotes from value
unquote() {
  local v=$1
  if [[ ${#v} -ge 2 && "$v" == \"*\" ]]; then
    v="${v:1:-1}"
  fi
  printf '%s' "$v"
}

while IFS= read -r line || [[ -n "$line" ]]; do
  line=$(trim "$line")
  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue
  if [[ "$line" == export\ * ]]; then
    line="${line#export }"
  fi
  if [[ "$line" != *=* ]]; then
    continue
  fi
  key="${line%%=*}"
  val="${line#*=}"
  key=$(trim "$key")
  val=$(trim "$val")
  key="${key//$'\r'/}"
  val="${val//$'\r'/}"
  val=$(unquote "$val")
  [[ -z "$key" ]] && continue
  VALS[$key]=$val
done < "$ENV_FILE"

# Aliases: restic-style names in .env → same KV as OCI_* (if OCI_* not set)
if [[ -n "${VALS[AWS_ACCESS_KEY_ID]:-}" && -z "${VALS[OCI_S3_ACCESS_KEY_ID]:-}" ]]; then
  VALS[OCI_S3_ACCESS_KEY_ID]=${VALS[AWS_ACCESS_KEY_ID]}
fi
if [[ -n "${VALS[AWS_SECRET_ACCESS_KEY]:-}" && -z "${VALS[OCI_S3_SECRET_ACCESS_KEY]:-}" ]]; then
  VALS[OCI_S3_SECRET_ACCESS_KEY]=${VALS[AWS_SECRET_ACCESS_KEY]}
fi

_put_kv() {
  local kv_name=$1
  local value=$2
  if [[ -z "$value" ]]; then
    echo "skip $kv_name (empty)" >&2
    return 0
  fi
  az keyvault secret set --vault-name "$AZURE_KEY_VAULT_NAME" --name "$kv_name" --value "$value" --only-show-errors >/dev/null
  echo "set $kv_name" >&2
}

for env_key in "${!ENV_TO_KV[@]}"; do
  kv_name="${ENV_TO_KV[$env_key]}"
  val="${VALS[$env_key]:-}"
  _put_kv "$kv_name" "$val"
done

echo "Done. Source: $ENV_FILE" >&2
echo "Ansible:" >&2
echo "  export AZURE_KEY_VAULT_URI=\$(az keyvault show -g vault-rg -n \"\$AZURE_KEY_VAULT_NAME\" --query properties.vaultUri -o tsv)" >&2
