# Firefly III Stack

## Context

- **Location:** docker/stacks/firefly
- **Compose file:** compose.yml
- **Data paths:**
  - /opt/homelab/data/firefly_iii/firefly_iii_db
  - /opt/homelab/data/firefly_iii/firefly_iii_upload

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/firefly/compose.yml up -d
```

## Access

- **App:** http://<node-ip>:82
- **Importer:** http://<node-ip>:81

## Notes

- Update FIREFLY_APP_KEY, FIREFLY_DB_PASSWORD, and FIREFLY_CRON_TOKEN in docker/.env.

## Production Notes

- Production restore uses a MariaDB logical dump plus restored upload/importer directories.
- The importer healthcheck validates the Apache process instead of relying on `wget` inside the image.
- Take a fresh OCI backup before upgrading Firefly.
