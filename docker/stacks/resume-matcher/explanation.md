# Resume Matcher Stack

## Context

- **Location:** `docker/stacks/resume-matcher`
- **Compose file:** `compose.yml`
- **Data path:** `/opt/homelab/data/resume-matcher_data`

## Overview

[Resume Matcher](https://github.com/srbhr/Resume-Matcher) is a self-hosted web app that helps tailor a resume to a job description using an AI provider.

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/resume-matcher/compose.yml up -d
```

## Access

- **Port:** `3010` (mapped to container port `3000`)
- **URL:** `http://<node-ip>:3010`

## AI provider configuration

Recommended: configure provider in the app UI (**Settings**) after first startup.

Optional defaults (Ollama example): set `LLM_PROVIDER`, `LLM_MODEL`, `LLM_API_BASE` in `compose.yml` or via `docker/.env` if you add those entries.

## Production Notes

- Backup uses OCI restic snapshots for `/opt/homelab/data/resume-matcher_data`.
- Update through the repo and redeploy with Ansible.
