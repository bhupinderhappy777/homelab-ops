# Immich Stack

## Context

- **Location:** docker/stacks/immich
- **Compose file:** compose.yml
- **Data paths:**
  - /opt/homelab/data/immich/uploads
  - /opt/homelab/data/immich/postgres
  - /opt/homelab/data/immich/immich_redis

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/immich/compose.yml up -d
```

## Access

- **Port:** 2283
- **URL:** http://<node-ip>:2283

## Notes

- Ensure vm.max_map_count is set to 262144 (handled by Ansible).
- IMMICH_DB_PASSWORD is required in docker/.env.

## Production Notes

- Production restore uses a PostgreSQL dump plus the `uploads` bind mount.
- `model-cache` is rebuildable and intentionally excluded from backup restore.
- Review upstream release notes before changing `IMMICH_VERSION` or image tags.
