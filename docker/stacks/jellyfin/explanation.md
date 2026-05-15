# Jellyfin Stack

## Context

- **Location:** docker/stacks/jellyfin
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/jellyfin_data/config
- **Media paths:** /opt/homelab/media and /mnt/media_storage

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/jellyfin/compose.yml up -d
```

## Access

- **Port:** 8096
- **URL:** http://<node-ip>:8096

## Notes

- Jellyfin cache uses a local named volume for performance.

## Production Notes

- The config directory should remain owned by `1002:1002`.
- Cache data is rebuildable and intentionally excluded from backup restore.
