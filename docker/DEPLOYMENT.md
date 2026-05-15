# Deployment Guide

This document describes the production workflow for bringing up a clean host,
hardening it with Ansible, deploying the full Docker Compose homelab, wiring a
Cloudflare Tunnel with a token, and restoring data from OCI Object Storage when
needed.

## 1. Provision the VM
Create the host with Terraform:

```bash
cd terraform
terraform init
terraform apply
```

## 2. Update Ansible inventory

Set the host IP and SSH user in [ansible/inventory/hosts.ini](../ansible/inventory/hosts.ini):

```ini
[azure_vm]
<YOUR_PUBLIC_IP> ansible_user=<YOUR_SSH_USER>
```

Use the same SSH user as Terraform `admin_username`.

## 3. Azure Key Vault and secrets (`vault-rg`)

Use the canonical steps in **[docs/README.md](../docs/README.md)** (Key Vault in `vault-rg`, `AZURE_KEY_VAULT_*` exports, YAML import or `seed_keyvault_hardcoded.example.sh`, and non-secret defaults in [ansible/vars/homelab_public.yml](../ansible/vars/homelab_public.yml)).

The deploy-time env file on the VM is rendered at `/opt/homelab/docker_stacks/docker/.env` from [ansible/roles/docker_stacks_deploy/templates/homelab.env.j2](../ansible/roles/docker_stacks_deploy/templates/homelab.env.j2).

## 4. Choose Deployment Mode

There are three normal modes:

1. Clean host, no data restore: run the playbook normally.
2. Clean host, restore from OCI backup: run the playbook with `-e backup_restore_snapshot=latest`.
3. One-time migration from an old host export: run the playbook with `-e migration_restore_archive_dir=/path/to/export`.

## 5. Legacy Migration Data

If you are doing a one-time migration from the old Swarm layout, copy the old data from `/home/adminuser/docker-data/...` into the new `/opt/homelab/data/...` paths before starting the stacks.

Examples:

```text
/home/adminuser/docker-data/openwebui_data            -> /opt/homelab/data/openwebui_data
/home/adminuser/docker-data/paperless_ngx            -> /opt/homelab/data/paperless_ngx
/home/adminuser/docker-data/firefly_iii              -> /opt/homelab/data/firefly_iii
/home/adminuser/docker-data/immich                   -> /opt/homelab/data/immich
/home/adminuser/docker-data/obsidian                 -> /opt/homelab/data/obsidian
/home/adminuser/docker-data/pihole_data              -> /opt/homelab/data/pihole_data
/home/adminuser/docker-data/jellyfin_data            -> /opt/homelab/data/jellyfin_data
/home/adminuser/docker-data/prometheus               -> /opt/homelab/data/prometheus
/home/adminuser/docker-data/grafana                  -> /opt/homelab/data/grafana
/home/adminuser/docker-data/loki                     -> /opt/homelab/data/loki
```

Also ensure these host paths still exist if you use them:

- `/mnt/media` for Immich read-only media imports
- `/mnt/media_storage` for Jellyfin extra media
- `/opt/homelab/media` for the shared media/downloads bind mount used by Jellyfin and n8n

## 6. Run the Playbook

Clean host deployment:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml --skip-tags migration_restore,backup_restore
```

Restore from OCI backup on first deploy:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  -e backup_restore_snapshot=latest
```

## Cloudflare Tunnel

The tunnel routing and public hostnames are managed in the Cloudflare dashboard.
This repo only:

- installs the `cloudflared` binary
- installs the systemd service with the supplied tunnel token
- ensures the service is enabled and running

That matches the intended production model: you create and manage the tunnel in
Cloudflare Zero Trust, and this repo only connects the host to it.

The dashboard should route public hostnames to host-published local ports.

Examples:

- `n8n.<domain>` -> `http://localhost:5678`
- `openwebui.<domain>` -> `http://localhost:3009`
- `paperless.<domain>` -> `http://localhost:8001`
- `immich.<domain>` -> `http://localhost:2283`
- `grafana.<domain>` -> `http://localhost:3005`
- `portainer.<domain>` -> `http://localhost:9000`

Make sure only the intended production host is running the production tunnel token at any given time.

## What the Playbook Does
1. `keyvault_secrets`: loads `vault_*` facts from Azure Key Vault in **`vault-rg`** (requires `AZURE_KEY_VAULT_URI`, `az login`).
2. `security_hardening`: applies the baseline Linux hardening tasks.
3. `base_docker`: installs Docker or Podman, `restic`, and S3-compatible CLI dependencies.
4. `docker_directories`: creates the exact bind-mount directories expected by the compose files under `/opt/homelab`.
5. `docker_stacks_deploy`: clones this repo to `/opt/homelab/docker_stacks`, renders `/opt/homelab/docker/.env`, and deploys the compose stacks.
6. `docker_backup_cron`: installs the OCI/restic backup and restore scripts, renders `/etc/homelab/restic.env`, and schedules nightly backups.
7. `docker_migration_restore`: one-time migration import (optional; currently commented out in [deploy-homelab.yml](../ansible/playbooks/deploy-homelab.yml) — enable the role if you use it).
8. `docker_backup_restore`: optionally restores from an OCI restic snapshot.
9. `cloudflared`: installs the Cloudflare Tunnel binary and starts the systemd service with the provided token.

## Will It Work If You Just Move Data and Run Ansible?
Usually yes, but only if all of the following are true:

1. Your migrated data lands in the exact new bind-mount paths under `/opt/homelab/data`.
2. All required secrets exist in Azure Key Vault (see `ansible/roles/keyvault_secrets/defaults/main.yml` for names).
3. `admin_username` in `vars/homelab_public.yml` (or overrides) matches the actual SSH/admin user on the VM.
4. `/mnt/media` and `/mnt/media_storage` exist if you rely on Immich or Jellyfin.

If any of those are wrong, the playbook may still complete, but some apps will start with empty directories, broken auth, or missing media mounts.

## Runtime Notes
The deploy path now supports both Docker and Podman. If you set `homelab_container_runtime: "podman"`, Ansible deploys stacks with `podman-compose` and also creates a `/usr/local/bin/docker` symlink to `podman` so helper commands can still work through the Docker-compatible CLI when available.

## Restore from Backup
If you need to restore onto a fresh VM from OCI Object Storage:

1. Complete the steps above.
2. Run the playbook with a snapshot selector:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  --skip-tags tunnel,ingress \
  -e backup_restore_snapshot=latest
```

Use a specific snapshot ID instead of `latest` when needed.

## Legacy Migration Restore

If you still have a one-time migration export directory from an old host, run:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  -e migration_restore_archive_dir=/path/to/export
```

## Nightly Backup

The deployed host runs a nightly restic backup at `03:00` by default. Each run:

1. creates fresh MariaDB/PostgreSQL dumps,
2. snapshots `/opt/homelab/data` incrementally with restic,
3. excludes live DB directories, monitoring data, caches, and Portainer state,
4. prunes snapshots to `7 daily / 4 weekly / 6 monthly`,
5. enforces a default `20GB` repository cap by removing the oldest snapshots if
   the OCI restic repository grows beyond the limit.

## Updating Applications

Update applications through the repo, not by changing containers manually on the host.

Recommended process:

1. Check upstream release notes.
2. Run a fresh manual backup:

```bash
ssh adminuser@ociubuntu "sudo CONTAINER_RUNTIME=docker /opt/homelab/docker_stacks/docker/scripts/backup.sh"
```

3. Change the pinned image tag or version reference in the relevant compose file.
4. Redeploy with Ansible.
5. Verify container health, logs, and the application UI locally before relying on Cloudflare.

For `immich`:

1. Update the `IMMICH_VERSION` or explicit image version.
2. Read the release notes for database or machine-learning changes.
3. Redeploy and verify all four containers plus `http://localhost:2283`.

For `paperless_ngx`:

1. Keep the image pinned and move deliberately between versions.
2. Redeploy and verify login, document list, database container, and worker logs.
3. If a migration fails, restore from the most recent OCI snapshot before trying a different version.

Version-sensitive notes:

- `paperless_ngx`: DB migrations can make rollback harder if you skip backups.
- `portainer`: state is disposable convenience state; recreate it rather than preserving incompatible DB files.
- `n8n`: older SQLite data may require schema repair when moving to newer images.
