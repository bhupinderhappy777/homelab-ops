# N8N Stack

## Context

- **Location:** docker/stacks/n8n
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/n8n_data
- **Media path:** /opt/homelab/media (optional)

## Overview

N8N is a workflow automation tool with a visual editor and many integrations.

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/n8n/compose.yml up -d
```

## Access

- **Port:** 5678
- **URL:** http://<node-ip>:5678

## Notes

- If you switch to the official image, update the image field in compose.yml.
- For Ollama integrations, add LLM variables to docker/.env and pass them through the service environment.

## Production Notes

- n8n stores state in SQLite under `/opt/homelab/data/n8n_data`.
- Restore scripts repair the `storedAt` column automatically for older SQLite files when needed.
- Workflow activation failures caused by missing node types are application-level issues, not core service health issues.
