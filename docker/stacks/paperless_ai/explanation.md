# Paperless AI Stack

## Context

- **Location:** docker/stacks/paperless_ai
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/paperless-ai_data

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/paperless_ai/compose.yml up -d
```

## Access

- **Port:** 3001
- **URL:** http://<node-ip>:3001

## Notes

- RAG integration settings are in the compose environment section.

## Production Notes

- The data directory should remain owned by `1000:1000`.
- Backup uses OCI restic snapshots for `/opt/homelab/data/paperless-ai_data`.
