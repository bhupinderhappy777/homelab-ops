# Docuseal Stack

## Context

- **Location:** docker/stacks/docuseal
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/docuseal_data

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/docuseal/compose.yml up -d
```

## Access

- **Port:** 3003
- **URL:** http://<node-ip>:3003

## Notes

- Postgres runs as a sidecar in the same compose file.
- Update DOCUSEAL_POSTGRES_PASSWORD in docker/.env.

## Production Notes

- Production restore uses a PostgreSQL dump plus restored `docuseal_data` files.
- Back up before changing Docuseal or Postgres image versions.
