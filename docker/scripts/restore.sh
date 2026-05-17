#!/usr/bin/env bash
set -euo pipefail

COMPOSE_CMD=(docker compose)
CONTAINER_CLI="docker"

if [[ -f /etc/homelab/restic.env ]]; then
  set -a
  . /etc/homelab/restic.env
  set +a
fi

SNAPSHOT_REF="${1:-latest}"
RESTORE_ROOT="${RESTORE_ROOT:-/tmp/homelab-restic-restore}"
RESTORED_DATA_ROOT="${RESTORE_ROOT}/opt/homelab/data"
RESTORED_DUMP_ROOT="${RESTORE_ROOT}/tmp/homelab-backup-payload/db-dumps"
TARGET_DATA_ROOT="/opt/homelab/data"
STACKS_ROOT="/opt/homelab/docker_stacks/docker/stacks"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Required environment variable missing: ${name}" >&2
    exit 1
  fi
}

find_container() {
  local prefix="$1"
  local prefix_pattern="${prefix//_/[-_]}"
  "${CONTAINER_CLI}" ps -a --format '{{.Names}}' | grep -E "^${prefix_pattern}([_-]|$)" | head -n1
}

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

  if ! "${CONTAINER_CLI}" logs --tail 50 "${name}" 2>&1 | grep -q 'Bad magic header in tc log'; then
    return 1
  fi

  echo "Detected MariaDB tc.log corruption for ${name}; removing stale tc.log"
  "${CONTAINER_CLI}" stop "${name}" >/dev/null 2>&1 || true
  rm -f "${data_dir}/tc.log"
  restart_compose_service "${stack}" "${service}"
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
      created|starting)
        sleep 5
        ;;
      '')
        sleep 2
        ;;
      *)
        echo "Container ${name} is in unexpected state: ${status}" >&2
        return 1
        ;;
    esac
  done

  echo "Timed out waiting for container ${name} to be running" >&2
  return 1
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

  wait_for_container_running "${prefix}" "${name}"
  "${CONTAINER_CLI}" exec "${name}" "$@"
}

exec_in_i() {
  local prefix="$1"
  shift
  local name

  name="$(find_container "${prefix}" || true)"
  if [[ -z "${name}" ]]; then
    echo "Container prefix not found: ${prefix}" >&2
    exit 1
  fi

  wait_for_container_running "${prefix}" "${name}"
  "${CONTAINER_CLI}" exec -i "${name}" "$@"
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

cleanup() {
  rm -rf "${RESTORE_ROOT}"
}

trap cleanup EXIT

require_env RESTIC_REPOSITORY
require_env RESTIC_PASSWORD
require_env AWS_ACCESS_KEY_ID
require_env AWS_SECRET_ACCESS_KEY
require_env AWS_DEFAULT_REGION

rm -rf "${RESTORE_ROOT}"
mkdir -p "${RESTORE_ROOT}"

echo "Restoring snapshot ${SNAPSHOT_REF}"
restic restore "${SNAPSHOT_REF}" --target "${RESTORE_ROOT}"

if [[ ! -d "${RESTORED_DATA_ROOT}" ]]; then
  echo "Restored data root not found: ${RESTORED_DATA_ROOT}" >&2
  exit 1
fi

mkdir -p "${TARGET_DATA_ROOT}"
cp -a "${RESTORED_DATA_ROOT}/." "${TARGET_DATA_ROOT}/"

repair_n8n_sqlite_if_needed

chown -R 1000:1000 "${TARGET_DATA_ROOT}/paperless-ai_data" "${TARGET_DATA_ROOT}/n8n_data" "${TARGET_DATA_ROOT}/uptime-kuma/data" 2>/dev/null || true
chown -R 1002:1002 "${TARGET_DATA_ROOT}/jellyfin_data/config" 2>/dev/null || true
chown -R 1002:1002 "${TARGET_DATA_ROOT}/transmission" "${TARGET_DATA_ROOT}/prowlarr" "${TARGET_DATA_ROOT}/radarr" "${TARGET_DATA_ROOT}/sonarr" 2>/dev/null || true
chown -R 1002:1002 "${TARGET_DATA_ROOT}/paperless_ngx/paperless_consume" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_media" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_data" "${TARGET_DATA_ROOT}/paperless_ngx/paperless_export" 2>/dev/null || true
chown -R 999:999 "${TARGET_DATA_ROOT}/paperless_ngx/paperless_redis" 2>/dev/null || true
# Docuseal image runs as 2000:2000; embedded Redis must write RDB under /data/docuseal.
chown -R 2000:2000 "${TARGET_DATA_ROOT}/docuseal_data" 2>/dev/null || true
chown -R 65534:65534 "${TARGET_DATA_ROOT}/prometheus/data" 2>/dev/null || true
chown -R 472:472 "${TARGET_DATA_ROOT}/grafana/data" 2>/dev/null || true
chown -R 10001:10001 "${TARGET_DATA_ROOT}/loki/data" 2>/dev/null || true

# Authentik data ownership
chown -R 1000:1000 "${TARGET_DATA_ROOT}/authentik/data" "${TARGET_DATA_ROOT}/authentik/certs" "${TARGET_DATA_ROOT}/authentik/custom-templates" "${TARGET_DATA_ROOT}/authentik/database" 2>/dev/null || true

if [[ -f "${RESTORED_DUMP_ROOT}/firefly_db.sql" ]]; then
  exec_in_i "firefly-db" sh -lc 'mariadb -ufirefly -p"$MYSQL_PASSWORD" firefly' < "${RESTORED_DUMP_ROOT}/firefly_db.sql"
fi
if [[ -f "${RESTORED_DUMP_ROOT}/monica_db.sql" ]]; then
  exec_in_i "monica-db" sh -lc 'mariadb -umonica -p"$MYSQL_PASSWORD" monica' < "${RESTORED_DUMP_ROOT}/monica_db.sql"
fi
if [[ -f "${RESTORED_DUMP_ROOT}/paperless_ngx_db.sql" ]]; then
  exec_in "paperless_ngx-db" psql -U paperless_user -d paperless_db -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO paperless_user; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "paperless_ngx-db" psql -U paperless_user -d paperless_db -v ON_ERROR_STOP=1 < "${RESTORED_DUMP_ROOT}/paperless_ngx_db.sql"
fi
if [[ -f "${RESTORED_DUMP_ROOT}/immich_db.sql" ]]; then
  exec_in "immich-database" psql -U postgres -d immich -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "immich-database" psql -U postgres -d immich -v ON_ERROR_STOP=1 < "${RESTORED_DUMP_ROOT}/immich_db.sql"
fi
if [[ -f "${RESTORED_DUMP_ROOT}/docuseal_db.sql" ]]; then
  exec_in "docuseal-postgres" psql -U postgres -d docuseal -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "docuseal-postgres" psql -U postgres -d docuseal -v ON_ERROR_STOP=1 < "${RESTORED_DUMP_ROOT}/docuseal_db.sql"
fi

if [[ -f "${RESTORED_DUMP_ROOT}/authentik_db.sql" ]]; then
  exec_in "authentik_postgresql" psql -U authentik -d authentik -v ON_ERROR_STOP=1 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO authentik; GRANT ALL ON SCHEMA public TO public;'
  exec_in_i "authentik_postgresql" psql -U authentik -d authentik -v ON_ERROR_STOP=1 < "${RESTORED_DUMP_ROOT}/authentik_db.sql"
fi

echo "Restore complete"
