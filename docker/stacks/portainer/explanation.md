# Portainer Stack

## Context

- **Location:** docker/stacks/portainer
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/portainer_data

## Overview

Portainer provides a web UI for managing the local Docker engine.

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/portainer/compose.yml up -d
```

## Access

- **HTTPS:** https://<node-ip>:9443
- **HTTP:** http://<node-ip>:9000
- **Edge:** http://<node-ip>:8000

## Production Notes

- Portainer state is treated as disposable convenience state.
- `portainer_data` is intentionally excluded from automated backup restore.
- If a new Portainer image cannot read old state, recreate it from an empty data directory.
