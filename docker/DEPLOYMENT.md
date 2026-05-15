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

Copy the example and set your VM address and SSH user:

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini
```

Edit `ansible/inventory/hosts.ini`:

```ini
[azure_vm]
<YOUR_PUBLIC_IP> ansible_user=<YOUR_SSH_USER>
```

Use the same SSH user as Terraform `admin_username`.

## 3. Azure Key Vault and secrets (`vault-rg`)

Use the canonical steps in **[docs/README.md](../docs/README.md)** (Key Vault in `vault-rg`, `AZURE_KEY_VAULT_*` exports, `az keyvault secret set`, and non-secret defaults in [ansible/vars/homelab_public.yml](../ansible/vars/homelab_public.yml)).

The deploy-time env file on the VM is rendered at `/opt/homelab/docker_stacks/docker/.env` from [ansible/roles/docker_stacks_deploy/templates/homelab.env.j2](../ansible/roles/docker_stacks_deploy/templates/homelab.env.j2).

## 4. Choose deployment mode

1. **Clean host, no OCI restore on this run:** run the playbook with `--skip-tags backup_restore` (typical redeploy when data already exists on disk).
2. **Clean host, restore from OCI:** run the playbook with `-e backup_restore_snapshot=latest`, or pass a specific restic snapshot id instead of `latest`.

Create these host paths before deploy if your stacks use them:

- `/mnt/media` — Immich read-only media imports
- `/mnt/media_storage` — Jellyfin extra media
- `/opt/homelab/media` — shared media/downloads for Jellyfin and n8n

## 5. Run the Playbook

**Steady-state deploy** (no restic restore this run):

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml --skip-tags backup_restore
```

**First boot or DR: restore from OCI** (requires Key Vault secrets for restic and DB access):

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
3. `base_docker`: installs Docker Engine (Compose plugin), `restic`, and S3-compatible CLI dependencies on Ubuntu/Debian.
4. `docker_directories`: creates the exact bind-mount directories expected by the compose files under `/opt/homelab`.
5. `docker_stacks_deploy`: clones this repo to `/opt/homelab/docker_stacks`, renders `/opt/homelab/docker/.env`, and deploys the compose stacks.
6. `docker_backup_cron`: installs the OCI/restic backup and restore scripts, renders `/etc/homelab/restic.env`, and schedules nightly backups.
7. `docker_backup_restore`: optionally restores from an OCI restic snapshot (`-e backup_restore_snapshot=...`).
8. `cloudflared`: installs the Cloudflare Tunnel binary and starts the systemd service with the provided token.
9. `tailscale`: installs and enrolls Tailscale when `vault_tailscale_auth_key` is set in Key Vault.

## Will It Work If You Copy Data and Run Ansible?
Usually yes, but only if all of the following are true:

1. Application data lives under the expected bind-mount paths under `/opt/homelab/data` (for example after a successful restic restore, or manual copy into those paths).
2. All required secrets exist in Azure Key Vault (see `ansible/roles/keyvault_secrets/defaults/main.yml` for names).
3. `admin_username` in `vars/homelab_public.yml` (or overrides) matches the actual SSH/admin user on the VM.
4. `/mnt/media` and `/mnt/media_storage` exist if you rely on Immich or Jellyfin.

If any of those are wrong, the playbook may still complete, but some apps will start with empty directories, broken auth, or missing media mounts.

## Runtime Notes
Stacks and host scripts assume **Docker Engine** with the Compose v2 CLI (`docker compose`) on Ubuntu Server.

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
ssh <your-admin-user>@<your-vm-hostname-or-ip> "sudo CONTAINER_RUNTIME=docker /opt/homelab/docker_stacks/docker/scripts/backup.sh"
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
3. If an upgrade fails, restore from the most recent OCI snapshot before trying a different version.

Version-sensitive notes:

- `paperless_ngx`: Django database migrations can make rollback harder if you skip backups.
- `portainer`: state is disposable convenience state; recreate it rather than preserving incompatible DB files.
- `n8n`: older SQLite data may require schema repair when moving to newer images.
