#!/usr/bin/env bash
set -euo pipefail

CONTAINER_CLI="${CONTAINER_CLI:-docker}"
SOURCE_DATA_ROOT="${SOURCE_DATA_ROOT:-$HOME/docker-data}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"
OUTPUT_DIR="${1:-$HOME/homelab-migration-$TIMESTAMP}"
SOURCE_PARENT="$(dirname "${SOURCE_DATA_ROOT}")"
SOURCE_BASENAME="$(basename "${SOURCE_DATA_ROOT}")"

# Keep the migration archive lean: databases are exported separately, and caches
# can be rebuilt on the target host.
EXCLUDES=(
  "${SOURCE_BASENAME}/docuseal_postgres"
  "${SOURCE_BASENAME}/firefly_iii/firefly_iii_db"
  "${SOURCE_BASENAME}/immich/postgres"
  "${SOURCE_BASENAME}/immich/immich_redis"
  "${SOURCE_BASENAME}/immich/model-cache"
  "${SOURCE_BASENAME}/jellyfin_data/cache"
  "${SOURCE_BASENAME}/loki"
  "${SOURCE_BASENAME}/monica/db"
  "${SOURCE_BASENAME}/open_webui_data"
  "${SOURCE_BASENAME}/openwebui_data"
  "${SOURCE_BASENAME}/paperless_ngx/paperless_postgres"
  "${SOURCE_BASENAME}/paperless_ngx/paperless_redis"
  "${SOURCE_BASENAME}/portainer_data"
  "${SOURCE_BASENAME}/portainer_data/compose"
  "${SOURCE_BASENAME}/prometheus"
  "${SOURCE_BASENAME}/grafana"
)

find_container() {
  local prefix="$1"
  local prefix_pattern="${prefix//_/[-_]}"
  "${CONTAINER_CLI}" ps --format '{{.Names}}' | grep -E "^${prefix_pattern}(\\.|[_-]|$)" | head -n1
}

dump_from_container() {
  local prefix="$1"
  shift
  local name
  name="$(find_container "$prefix" || true)"
  if [[ -z "${name}" ]]; then
    echo "WARN: container prefix ${prefix} not found" >&2
    return 1
  fi
  "${CONTAINER_CLI}" exec "${name}" "$@"
}

mkdir -p "${OUTPUT_DIR}"

if [[ ! -d "${SOURCE_DATA_ROOT}" ]]; then
  echo "Source data root not found: ${SOURCE_DATA_ROOT}" >&2
  exit 1
fi

echo "Exporting live database dumps into ${OUTPUT_DIR}"
dump_from_container "paperless_ngx-db" pg_dump -U paperless_user paperless_db > "${OUTPUT_DIR}/paperless_ngx_db.sql" || true
dump_from_container "docuseal-postgres" pg_dump -U postgres docuseal > "${OUTPUT_DIR}/docuseal_db.sql" || true
dump_from_container "immich-database" pg_dump -U postgres immich > "${OUTPUT_DIR}/immich_db.sql" || true
dump_from_container "firefly-db" sh -lc 'mariadb-dump -ufirefly -p"$MYSQL_PASSWORD" firefly' > "${OUTPUT_DIR}/firefly_db.sql" || true
dump_from_container "monica-db" sh -lc 'mariadb-dump -umonica -p"$MYSQL_PASSWORD" monica' > "${OUTPUT_DIR}/monica_db.sql" || true

echo "Archiving ${SOURCE_DATA_ROOT}"
TAR_EXCLUDES=()
for exclude in "${EXCLUDES[@]}"; do
  TAR_EXCLUDES+=("--exclude=${exclude}")
done

if command -v sudo >/dev/null 2>&1; then
  sudo tar -C "${SOURCE_PARENT}" -cf - "${TAR_EXCLUDES[@]}" "${SOURCE_BASENAME}" | gzip > "${OUTPUT_DIR}/docker-data.tar.gz"
else
  tar -C "${SOURCE_PARENT}" -cf - "${TAR_EXCLUDES[@]}" "${SOURCE_BASENAME}" | gzip > "${OUTPUT_DIR}/docker-data.tar.gz"
fi

cat > "${OUTPUT_DIR}/manifest.txt" <<EOF
timestamp=${TIMESTAMP}
source_data_root=${SOURCE_DATA_ROOT}
container_cli=${CONTAINER_CLI}
host=$(hostname)
archive_excludes=${EXCLUDES[*]}
EOF

sha256sum "${OUTPUT_DIR}"/* > "${OUTPUT_DIR}/sha256sums.txt"

echo "Migration export ready at ${OUTPUT_DIR}"
