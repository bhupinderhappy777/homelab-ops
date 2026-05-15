# Uptime Kuma Stack

## Context

- **Location:** docker/stacks/uptime-kuma
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/uptime-kuma/data
- **Monitor list:** see MONITORS.md

## Overview

Uptime Kuma provides HTTP(s), TCP, and keyword monitoring with a clean UI and alerting.

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/uptime-kuma/compose.yml up -d
```

## Access

- **Port:** 3002 (mapped to container port 3001)
- **URL:** http://<node-ip>:3002

## Notes

- Add monitors via the UI using the targets in MONITORS.md.
- The compose file attaches Kuma to other stack networks so it can reach internal health endpoints.

## Production Notes

- The data directory should remain owned by `1000:1000`.
- Backup uses OCI restic snapshots for the embedded database and monitor configuration.
