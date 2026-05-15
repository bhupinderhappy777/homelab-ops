This folder contains Docker Compose stacks and scripts deployed through Ansible.

## Overview

1. `stacks/` contains `compose.yml` for each self-hosted service.
2. `scripts/` includes `backup.sh`, `restore.sh`, and `deploy.sh`.
3. `.env.example` mirrors variables Ansible renders into `/opt/homelab/docker_stacks/docker/.env` during provisioning.

## Ansible-managed deployments

For production deploys, Ansible is the source of truth:

1. Seed Azure Key Vault and set `AZURE_KEY_VAULT_URI` (see root `README.md` and [docs/README.md](../docs/README.md)).
2. Run `ansible/playbooks/deploy-homelab.yml`.

The same playbook wires **nightly OCI restic backups** (`docker_backup_cron`) and optional **OCI snapshot restore** (`docker_backup_restore` when `backup_restore_snapshot` is set).

Cloudflare Tunnel is not a Compose stack here: Ansible installs the `cloudflared` systemd service from a Key Vault–backed token.

## Adding a new service

Use [ADDING_SERVICE.md](ADDING_SERVICE.md) for the end-to-end workflow.

A new service is only complete when:

- its compose file exists,
- Ansible creates its bind mounts,
- Ansible deploys it,
- backup/restore behavior is decided.
- [docker/DEPLOYMENT.md](DEPLOYMENT.md) is updated if tunnel routes or notable ports change.

## Updating stack versions

For production updates:

1. Change the pinned image tag or version reference in the stack compose file.
2. Run a fresh manual backup.
3. Redeploy through Ansible.
4. Validate health, logs, and the application endpoint.

Do not change image versions only on the host if you want future playbook runs to stay consistent.

The template for the generated `.env` on the VM is [ansible/roles/docker_stacks_deploy/templates/homelab.env.j2](../ansible/roles/docker_stacks_deploy/templates/homelab.env.j2).

## Deploying locally (development)

Copy the environment template and fill values:

```bash
cp .env.example .env
```

Start a single stack:

```bash
bash scripts/deploy.sh <stack-name>
```

Example:

```bash
bash scripts/deploy.sh pihole
```
