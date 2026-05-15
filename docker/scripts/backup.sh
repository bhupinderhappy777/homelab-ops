#!/usr/bin/env bash
set -euo pipefail

CONTAINER_CLI="docker"

if [[ -f /etc/homelab/restic.env ]]; then
  set -a
  . /etc/homelab/restic.env
  set +a
fi

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
DATA_ROOT="${DATA_ROOT:-/opt/homelab/data}"
BACKUP_ROOT="${BACKUP_ROOT:-/tmp/homelab-backup-payload}"
DB_DUMP_DIR="${BACKUP_ROOT}/db-dumps"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"
HOSTNAME_TAG="$(hostname -s)"
KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"
MAX_REPO_SIZE_GB="${RESTIC_MAX_REPO_SIZE_GB:-20}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Required environment variable missing: ${name}" >&2
    exit 1
  fi
}

repo_size_bytes() {
  restic stats --mode raw-data --json | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("total_size", 0))'
}

oldest_snapshot_id() {
  restic snapshots --json | python3 -c 'import json,sys; snaps=json.load(sys.stdin); snaps.sort(key=lambda s: s.get("time", "")); print(snaps[0]["id"] if snaps else "")'
}

enforce_repo_size_cap() {
  local max_bytes current_bytes oldest_id
  max_bytes=$(MAX_REPO_SIZE_GB="${MAX_REPO_SIZE_GB}" python3 - <<'PY'
import os
print(int(float(os.environ["MAX_REPO_SIZE_GB"]) * 1024 * 1024 * 1024))
PY
)

  current_bytes="$(repo_size_bytes)"
  while [[ "${current_bytes}" -gt "${max_bytes}" ]]; do
    oldest_id="$(oldest_snapshot_id)"
    if [[ -z "${oldest_id}" ]]; then
      echo "No snapshots available to prune while enforcing repo size cap" >&2
      break
    fi

    echo "Repository size ${current_bytes} bytes exceeds ${max_bytes}; pruning oldest snapshot ${oldest_id}"
    restic forget "${oldest_id}" --prune
    current_bytes="$(repo_size_bytes)"
  done

  echo "Repository size after enforcement: ${current_bytes} bytes"
}

find_container() {
  local prefix="$1"
  local prefix_pattern="${prefix//_/[-_]}"
  "${CONTAINER_CLI}" ps --format '{{.Names}}' | grep -E "^${prefix_pattern}([_-]|$)" | head -n1
}

exec_in() {
  local prefix="$1"
  shift
  local name

  name="$(find_container "${prefix}" || true)"
  if [[ -z "${name}" ]]; then
    echo "Container prefix not found: ${prefix}" >&2
    exit 1
  fi

  "${CONTAINER_CLI}" exec "${name}" "$@"
}

cleanup() {
  rm -rf "${BACKUP_ROOT}"
}

trap cleanup EXIT

require_env RESTIC_REPOSITORY
require_env RESTIC_PASSWORD
require_env AWS_ACCESS_KEY_ID
require_env AWS_SECRET_ACCESS_KEY
require_env AWS_DEFAULT_REGION

mkdir -p "${DB_DUMP_DIR}"

echo "Creating database dumps in ${DB_DUMP_DIR}"
exec_in "paperless_ngx-db" pg_dump -U paperless_user paperless_db > "${DB_DUMP_DIR}/paperless_ngx_db.sql"
exec_in "docuseal-postgres" pg_dump -U postgres docuseal > "${DB_DUMP_DIR}/docuseal_db.sql"
exec_in "immich-database" pg_dump -U postgres immich > "${DB_DUMP_DIR}/immich_db.sql"
exec_in "firefly-db" sh -lc 'mariadb-dump -ufirefly -p"$MYSQL_PASSWORD" firefly' > "${DB_DUMP_DIR}/firefly_db.sql"
exec_in "monica-db" sh -lc 'mariadb-dump -umonica -p"$MYSQL_PASSWORD" monica' > "${DB_DUMP_DIR}/monica_db.sql"

cat > "${BACKUP_ROOT}/manifest.txt" <<EOF
timestamp=${TIMESTAMP}
host=${HOSTNAME_TAG}
container_runtime=docker
data_root=${DATA_ROOT}
restic_repository=${RESTIC_REPOSITORY}
EOF

if ! restic snapshots >/dev/null 2>&1; then
  echo "Initializing restic repository"
  restic init
fi

echo "Creating restic snapshot"
restic backup \
  --tag homelab \
  --tag "host:${HOSTNAME_TAG}" \
  --tag daily \
  --exclude "${DATA_ROOT}/docuseal_postgres" \
  --exclude "${DATA_ROOT}/paperless_ngx/paperless_postgres" \
  --exclude "${DATA_ROOT}/paperless_ngx/paperless_redis" \
  --exclude "${DATA_ROOT}/immich/postgres" \
  --exclude "${DATA_ROOT}/immich/immich_redis" \
  --exclude "${DATA_ROOT}/immich/model-cache" \
  --exclude "${DATA_ROOT}/firefly_iii/firefly_iii_db" \
  --exclude "${DATA_ROOT}/monica/db" \
  --exclude "${DATA_ROOT}/prometheus" \
  --exclude "${DATA_ROOT}/grafana" \
  --exclude "${DATA_ROOT}/loki" \
  --exclude "${DATA_ROOT}/portainer_data" \
  --exclude "${DATA_ROOT}/jellyfin/cache" \
  --exclude "${DATA_ROOT}/openwebui_data/cache" \
  "${DATA_ROOT}" \
  "${BACKUP_ROOT}"

echo "Applying retention policy"
restic forget --prune \
  --keep-daily "${KEEP_DAILY}" \
  --keep-weekly "${KEEP_WEEKLY}" \
  --keep-monthly "${KEEP_MONTHLY}"

echo "Enforcing repository size cap"
enforce_repo_size_cap

echo "Backup complete"
