# Docker Stacks

This folder contains all Docker Swarm stacks converted to standalone `docker compose`.
These are deployed natively through the Ansible pipeline.

## Overview

1. `stacks/` contains the converted `compose.yml` for all self-hosted services.
2. `scripts/` contains deployment and utility tools.
3. `.env.example` mirrors the variables that Ansible renders into `/opt/homelab/docker_stacks/docker/.env` during provisioning.

## Ansible-Managed Deployments

For production deploys, Ansible is the source of truth:

1. Provision Key Vault with Terraform and import secrets (`ansible/scripts/import_vars_yaml_to_keyvault.py`).
2. Set `AZURE_KEY_VAULT_URI` and run `ansible/playbooks/deploy-homelab.yml` (see root `README.md` and `ansible/README-ansible.md`).

Nightly OCI backups and OCI snapshot restores are also managed through the same
playbook:

- backup scheduling comes from `docker_backup_cron`
- one-time migration restore comes from `docker_migration_restore`
- OCI snapshot restore comes from `docker_backup_restore`

Cloudflare Tunnel is not defined as a Docker stack anymore. The production path
uses the `cloudflared` system service installed by Ansible from a tunnel token.

## Adding A New Service

Use `docker/ADDING_SERVICE.md` for the required end-to-end workflow.

A new service is only complete when:

- its compose file exists,
- Ansible creates its bind mounts,
- Ansible deploys it,
- backup/restore behavior is decided,
- and its explanation doc is updated.

## Updating Stack Versions

For production updates:

1. change the image tag or version reference in the stack compose file,
2. run a fresh backup,
3. redeploy through Ansible,
4. validate health, logs, and the local application endpoint.

Do not mutate image versions directly on the host if you want future playbook runs to remain consistent.

The template used for the generated `.env` file is [ansible/roles/docker_stacks_deploy/templates/homelab.env.j2](../ansible/roles/docker_stacks_deploy/templates/homelab.env.j2).

If you are migrating from the old Swarm layout, move data from `/home/adminuser/docker-data/...` to the matching `/opt/homelab/data/...` paths before running the playbook.

## Deploying Locally

First copy the environment variables template and fill out the details:
```bash
cp .env.example .env
```
Update `.env` with actual sensible variables.

Then, start a stack using:
```bash
bash scripts/deploy.sh <stack-name>
```

For instance:
```bash
bash scripts/deploy.sh pihole
```
