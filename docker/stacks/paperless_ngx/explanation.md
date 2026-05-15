# Paperless NGX Stack

## Context

- **Location:** docker/stacks/paperless_ngx
- **Compose file:** compose.yml
- **Data paths:**
  - /opt/homelab/data/paperless_ngx/paperless_data
  - /opt/homelab/data/paperless_ngx/paperless_media
  - /opt/homelab/data/paperless_ngx/paperless_consume
  - /opt/homelab/data/paperless_ngx/paperless_export

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/paperless_ngx/compose.yml up -d
```

## Access

- **Port:** 8001
- **URL:** http://<node-ip>:8001

## Notes

- Database credentials come from docker/.env.
- Paperless uses Postgres and Redis sidecars in the same compose file.

## Production Notes

- The application data directories should be owned by `1002:1002`.
- The Redis data directory should be owned by `999:999`.
- Production restore uses a PostgreSQL dump plus restored file data.
- Keep the image pinned and take an OCI backup before changing versions.
