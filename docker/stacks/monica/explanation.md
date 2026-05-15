# Monica Stack

## Context

- **Location:** docker/stacks/monica
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/monica/data
- **DB path:** /opt/homelab/data/monica/db

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/monica/compose.yml up -d
```

## Access

- **Port:** 8080
- **URL:** http://<node-ip>:8080

## Notes

- Set MONICA_DB_PASSWORD and MONICA_APP_KEY in docker/.env.

## Production Notes

- Production restore uses a MariaDB dump plus restored Monica application storage.
- Take a fresh backup before changing Monica or MariaDB versions.
