# Homelab Backup Strategy

This homelab uses database dumps plus `restic` snapshots stored in OCI Object
Storage via the S3-compatible API.

Do not rely on direct tars of live database directories as the primary backup.
They are useful as an emergency extra, but they are not a consistent restore
format for PostgreSQL, MariaDB, SQLite, or embedded app databases unless the
service is stopped or the filesystem snapshot is crash-consistent.

## Source Of Truth

Use Git for:

- Terraform and Ansible code
- compose files
- backup and restore scripts
- generated-template definitions
- non-secret documentation

Use Ansible Vault or another secret manager for:

- application secrets and app keys
- database passwords
- Cloudflare tunnel token
- S3/object-storage credentials

Use object storage backups for:

- database dumps captured before every snapshot
- application file data through incremental encrypted snapshots
- media and document uploads
- a backup manifest

## Backup Shape

Each snapshot payload should contain:

- `db-dumps/docuseal_db.sql`
- `db-dumps/firefly_db.sql`
- `db-dumps/immich_db.sql`
- `db-dumps/monica_db.sql`
- `db-dumps/paperless_ngx_db.sql`
- `manifest.txt`
- a restic snapshot of `/opt/homelab/data`

The database dumps are mandatory for stateful services. This was proven during
local restore testing: Docuseal attachments existed on disk, but the app went to
setup mode until `docuseal.sql` was restored.

## Filesystem Snapshot

Snapshot `/opt/homelab/data`, excluding live database/cache directories that are
covered by dumps or are rebuildable:

- `/opt/homelab/data/docuseal_postgres`
- `/opt/homelab/data/paperless_ngx/paperless_postgres`
- `/opt/homelab/data/paperless_ngx/paperless_redis`
- `/opt/homelab/data/immich/postgres`
- `/opt/homelab/data/immich/immich_redis`
- `/opt/homelab/data/firefly_iii/firefly_iii_db`
- `/opt/homelab/data/monica/db`
- `/opt/homelab/data/grafana`
- `/opt/homelab/data/prometheus`
- `/opt/homelab/data/loki`
- `/opt/homelab/data/portainer_data`
- transient caches such as Jellyfin cache or Immich model cache

If the host uses filesystem-level snapshots, a stopped-service or
crash-consistent snapshot can be kept as a secondary safety net. It should not
replace logical dumps.

## Restore Order

1. Provision the host with Terraform and Ansible.
2. Deploy the compose stacks so database containers exist.
3. Run the Ansible restore flow with `backup_restore_snapshot=<snapshot|latest>`.
4. Restore `/opt/homelab/data` from restic.
5. Reset PostgreSQL `public` schemas for Docuseal, Paperless, and Immich.
6. Import MariaDB/PostgreSQL dumps.
7. Restart the application stacks.
8. Verify row counts and HTTP endpoints.

PostgreSQL dumps in this repo are plain SQL dumps. They should be restored into
an empty schema. Replaying them over an initialized database can produce
duplicate-object errors and broken foreign-key ordering.

MariaDB dumps include `DROP TABLE IF EXISTS`, so they are safer to replay into
an existing database, though restoring into a fresh database is still cleaner.

## Restore drills

Periodically restore onto a clean VM or alternate data directory using `backup_restore_snapshot` and the checklist earlier in this document. Validate row counts, HTTP health, and application-specific smoke tests after each drill.

## Runtime Notes

- Fedora/SELinux requires `:Z` on private persistent bind mounts.
- Shared read-only media mounts may need no relabel option if the filesystem
  does not allow xattrs.
- Rootless Podman cannot bind low ports such as `53`, `81`, or `82` without a
  host sysctl. Prefer high local ports, or run Pi-hole as a deliberate rootful
  exception.
- Portainer data is version-sensitive and excluded from automated backup restore.
  Treat it as convenience state and recreate it when possible.
- `n8n` uses SQLite by default here; if it matters, migrate it to Postgres later
  so it joins the logical-dump backup flow.

## Recommended Policy

- Nightly: logical DB dumps plus a `restic` snapshot pushed to OCI Object Storage.
- Weekly: full stopped-service filesystem snapshot or NAS copy.
- Monthly: restore drill onto a clean host or alternate data directory.
- Before upgrades: one manual backup plus notes of image versions.
- Retention: 7 daily, 4 weekly, 6 monthly, adjusted for storage cost.
- Repository cap: `RESTIC_MAX_REPO_SIZE_GB` defaults to `20`. After normal
  retention pruning, the backup script removes the oldest snapshots until the
  restic repository is back under the cap.
