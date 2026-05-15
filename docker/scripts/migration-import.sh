#!/usr/bin/env bash
set -euo pipefail

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
if [[ "${CONTAINER_RUNTIME}" == "podman" ]] && command -v podman-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(podman-compose)
else
  COMPOSE_CMD=("${CONTAINER_RUNTIME}" compose)
fi

if [[ "${CONTAINER_RUNTIME}" == "podman" ]] && command -v docker >/dev/null 2>&1; then
  CONTAINER_CLI="docker"
else
  CONTAINER_CLI="${CONTAINER_RUNTIME}"
fi

ARCHIVE_DIR="${1:-}"
if [[ -z "${ARCHIVE_DIR}" || ! -d "${ARCHIVE_DIR}" ]]; then
  echo "Usage: $0 <archive_dir>" >&2
  exit 1
fi

# Use /var/oled/tmp if available (larger partition on Oracle Linux), else /tmp
if [[ -d "/var/oled/tmp" ]]; then
  WORK_DIR="/var/oled/tmp/homelab-migration-import"
else
  WORK_DIR="/tmp/homelab-migration-import"
fi
SOURCE_TREE="${WORK_DIR}/docker-data"
TARGET_DATA_ROOT="/opt/homelab/data"
STACKS_ROOT="/opt/homelab/docker_stacks/docker/stacks"

restart_compose_service() {
  local stack="$1"
  local service="$2"
  (
    cd "${STACKS_ROOT}/${stack}"
    "${COMPOSE_CMD[@]}" --env-file /opt/homelab/docker_stacks/docker/.env up -d "${service}"
  )
}

repair_mariadb_tc_log_if_needed() {
  local prefix="$1"
  local data_dir=""
  local stack=""
  local service=""
  local name

  case "${prefix}" in
    firefly-db)
      data_dir="${TARGET_DATA_ROOT}/firefly_iii/firefly_iii_db"
      stack="firefly"
      service="db"
      ;;
    monica-db)
      data_dir="${TARGET_DATA_ROOT}/monica/db"
      stack="monica"
      service="db"
      ;;
    *)
      return 1
      ;;
  esac

  name="$(find_container "${prefix}" || true)"
  if [[ -z "${name}" ]]; then
    return 1
  fi

  if ! ${CONTAINER_CLI} logs --tail 50 "${name}" 2>&1 | grep -q 'Bad magic header in tc log'; then
    return 1
  fi

  echo "Detected MariaDB tc.log corruption for ${name}; removing stale tc.log and restarting ${stack}/${service}"
  ${CONTAINER_CLI} stop "${name}" >/dev/null 2>&1 || true
  rm -f "${data_dir}/tc.log"
  restart_compose_service "${stack}" "${service}"
  return 0
}

find_container() {
  local prefix="$1"
  local prefix_pattern="${prefix//_/[-_]}"
  ${CONTAINER_CLI} ps -a --format '{{.Names}}' | grep -E "^${prefix_pattern}([_-]|$)" | head -n1
}

wait_for_container_running() {
  local prefix="$1"
  local name="$2"
  local status

  for _ in $(seq 1 60); do
    status="$(${CONTAINER_CLI} inspect --format '{{.State.Status}}' "${name}" 2>/dev/null || true)"
    case "${status}" in
      running)
        return 0
        ;;
      restarting)
        repair_mariadb_tc_log_if_needed "${prefix}" || true
        sleep 5
        ;;
      created|restarting|starting)
        sleep 5
        ;;
      '')
        sleep 2
        ;;
      *)
        echo "WARN: container ${name} is in unexpected state: ${status}" >&2
        return 1
        ;;
    esac
  done

  echo "WARN: timed out waiting for container ${name} to be running" >&2
  return 1
}

exec_in() {
  local prefix="$1"
  shift
  local name
  name="$(find_container "$prefix" || true)"
  if [[ -z "${name}" ]]; then
    echo "WARN: container prefix ${prefix} not found" >&2
    return 1
  fi
  wait_for_container_running "${prefix}" "${name}"
  "${CONTAINER_CLI}" exec "$name" "$@"
}

exec_in_i() {
  local prefix="$1"
  shift
  local name
  name="$(find_container "$prefix" || true)"
  if [[ -z "${name}" ]]; then
    echo "WARN: container prefix ${prefix} not found" >&2
    return 1
  fi
  wait_for_container_running "${prefix}" "${name}"
  "${CONTAINER_CLI}" exec -i "$name" "$@"
}

copy_tree() {
  local src="$1"
  local dst="$2"
  if [[ -d "${src}" ]]; then
    mkdir -p "${dst}"
    cp -a "${src}/." "${dst}/"
  fi
}

repair_n8n_sqlite_if_needed() {
  local db_path
  for db_path in "${TARGET_DATA_ROOT}/n8n_data/database.sqlite" "${TARGET_DATA_ROOT}/n8n_data/.n8n/database.sqlite"; do
    if [[ -f "${db_path}" ]]; then
      python3 - <<PY
import sqlite3
path = ${db_path@Q}
conn = sqlite3.connect(path)
cur = conn.cursor()
cols = [r[1] for r in cur.execute('PRAGMA table_info(execution_entity)').fetchall()]
if 'storedAt' not in cols:
    cur.execute("ALTER TABLE execution_entity ADD COLUMN storedAt VARCHAR(2) NOT NULL DEFAULT 'db' CHECK(storedAt IN ('db','fs','s3'))")
    conn.commit()
conn.close()
PY
    fi
  done
}

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
tar -xzf "${ARCHIVE_DIR}/docker-data.tar.gz" -C "${WORK_DIR}"

copy_tree "${SOURCE_TREE}/docuseal_data" "${TARGET_DATA_ROOT}/docuseal_data"
copy_tree "${SOURCE_TREE}/firefly_iii/firefly_iii_importer" "${TARGET_DATA_ROOT}/firefly_iii/firefly_iii_importer"
copy_tree "${SOURCE_TREE}/firefly_iii/firefly_iii_upload" "${TARGET_DATA_ROOT}/firefly_iii/firefly_iii_upload"
copy_tree "${SOURCE_TREE}/grafana/data" "${TARGET_DATA_ROOT}/grafana/data"
copy_tree "${SOURCE_TREE}/immich/uploads" "${TARGET_DATA_ROOT}/immich/uploads"
copy_tree "${SOURCE_TREE}/immich/model-cache" "${TARGET_DATA_ROOT}/immich/model-cache"
copy_tree "${SOURCE_TREE}/jellyfin_data/config" "${TARGET_DATA_ROOT}/jellyfin_data/config"
copy_tree "${SOURCE_TREE}/loki/data" "${TARGET_DATA_ROOT}/loki/data"
copy_tree "${SOURCE_TREE}/monica/data" "${TARGET_DATA_ROOT}/monica/data"
copy_tree "${SOURCE_TREE}/n8n_data" "${TARGET_DATA_ROOT}/n8n_data"
copy_tree "${SOURCE_TREE}/obsidian/couchdb/data" "${TARGET_DATA_ROOT}/obsidian/couchdb/data"
copy_tree "${SOURCE_TREE}/obsidian/couchdb-etc" "${TARGET_DATA_ROOT}/obsidian/couchdb-etc"
copy_tree "${SOURCE_TREE}/openwebui_data" "${TARGET_DATA_ROOT}/openwebui_data"
if [[ ! -d "${SOURCE_TREE}/openwebui_data" && -d "${SOURCE_TREE}/open_webui_data" ]]; then
  copy_tree "${SOURCE_TREE}/open_webui_data" "${TARGET_DATA_ROOT}/openwebui_data"
fi
copy_tree "${SOURCE_TREE}/paperless-ai_data" "${TARGET_DATA_ROOT}/paperless-ai_data"
copy_tree "${SOURCE_TREE}/paperless_ngx/paperless_consume" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_consume"
copy_tree "${SOURCE_TREE}/paperless_ngx/paperless_data" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_data"
copy_tree "${SOURCE_TREE}/paperless_ngx/paperless_export" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_export"
copy_tree "${SOURCE_TREE}/paperless_ngx/paperless_media" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_media"
copy_tree "${SOURCE_TREE}/pihole_data/pihole" "${TARGET_DATA_ROOT}/pihole_data/pihole"
copy_tree "${SOURCE_TREE}/pihole_data/dnsmasq.d" "${TARGET_DATA_ROOT}/pihole_data/dnsmasq.d"
copy_tree "${SOURCE_TREE}/prometheus/data" "${TARGET_DATA_ROOT}/prometheus/data"
copy_tree "${SOURCE_TREE}/resume-matcher_data" "${TARGET_DATA_ROOT}/resume-matcher_data"
copy_tree "${SOURCE_TREE}/uptime-kuma/data" "${TARGET_DATA_ROOT}/uptime-kuma/data"

repair_n8n_sqlite_if_needed

# The migration archive intentionally excludes live DB directories and rebuildable
# caches. Those are restored from SQL dumps or recreated by the containers.
echo "Restoring SQL dumps into running database containers"
if [[ -f "${ARCHIVE_DIR}/firefly_db.sql" ]]; then
  exec_in_i "firefly-db" sh -lc 'mariadb -ufirefly -p"$MYSQL_PASSWORD" firefly' < "${ARCHIVE_DIR}/firefly_db.sql"
fi
if [[ -f "${ARCHIVE_DIR}/monica_db.sql" ]]; then
  exec_in_i "monica-db" sh -lc 'mariadb -umonica -p"$MYSQL_PASSWORD" monica' < "${ARCHIVE_DIR}/monica_db.sql"
fi
if [[ -f "${ARCHIVE_DIR}/paperless_ngx_db.sql" ]]; then
  exec_in "paperless_ngx-db" psql -U paperless_user -d paperless_db -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO paperless_user; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "paperless_ngx-db" psql -U paperless_user -d paperless_db -v ON_ERROR_STOP=1 < "${ARCHIVE_DIR}/paperless_ngx_db.sql"
fi
if [[ -f "${ARCHIVE_DIR}/immich_db.sql" ]]; then
  exec_in "immich-database" psql -U postgres -d immich -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "immich-database" psql -U postgres -d immich -v ON_ERROR_STOP=1 < "${ARCHIVE_DIR}/immich_db.sql"
fi
if [[ -f "${ARCHIVE_DIR}/docuseal_db.sql" ]]; then
  exec_in "docuseal-postgres" psql -U postgres -d docuseal -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "docuseal-postgres" psql -U postgres -d docuseal -v ON_ERROR_STOP=1 < "${ARCHIVE_DIR}/docuseal_db.sql"
fi

chown -R 1000:1000 "${TARGET_DATA_ROOT}/paperless-ai_data" "${TARGET_DATA_ROOT}/n8n_data" "${TARGET_DATA_ROOT}/uptime-kuma/data" || true
chown -R 1002:1002 "${TARGET_DATA_ROOT}/jellyfin_data/config" || true
chown -R 1002:1002 "${TARGET_DATA_ROOT}/paperless_ngx/paperless_consume" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_media" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_data" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_export" || true
chown -R 999:999 "${TARGET_DATA_ROOT}/paperless_ngx/paperless_redis" || true
chown -R 65534:65534 "${TARGET_DATA_ROOT}/prometheus/data" || true
chown -R 472:472 "${TARGET_DATA_ROOT}/grafana/data" || true
chown -R 10001:10001 "${TARGET_DATA_ROOT}/loki/data" || true

echo "Migration import complete"
