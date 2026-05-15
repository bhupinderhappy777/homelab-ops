# Open WebUI Stack

## Context

- **Location:** docker/stacks/openwebui
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/openwebui_data
- **Secret:** OPENWEBUI_SECRET_KEY in docker/.env

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/openwebui/compose.yml up -d
```

## Access

- **Port:** 3009
- **URL:** http://<node-ip>:3009

## Notes

- Set OPENWEBUI_SECRET_KEY after first deploy if you rotate secrets.
- For Ollama on the host, set OLLAMA_BASE_URL in the compose environment.

## Production Notes

- Backup uses OCI restic snapshots for `/opt/homelab/data/openwebui_data`.
- Update through the repo and redeploy with Ansible rather than mutating the host container directly.
