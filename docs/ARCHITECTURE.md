# Architecture

## Platform

The automation and Compose bind mounts are written for **Ubuntu Server** with **Docker Engine** (default). **Podman** remains optional via `homelab_container_runtime: "podman"` if you prefer it on a compatible host.

## Repository layout

| Path | Role |
|------|------|
| `terraform/` | Azure resource group, VNet, subnet, NSG, public IP, NIC, Linux VM (Spot-capable), optional Key Vault resources for lab use. |
| `ansible/` | Playbooks, inventory, `vars/homelab_public.yml` (committed defaults), roles: Key Vault facts, **Linux-only** OS hardening (`security_hardening` for RedHat/Debian), Docker/Podman, data dirs, stack deploy, backup cron, restore, tunnel, Tailscale, chezmoi. |
| `docker/stacks/` | One directory per Compose project; cloned/checked out on the VM under `/opt/homelab/docker_stacks/docker/stacks/`. |
| `docker/scripts/` | `backup.sh`, `restore.sh`, etc.; copied to the VM by Ansible. |

## Where things run

- **Control machine:** `az login`, `ansible-playbook`, Key Vault reads (`delegate_to: localhost` in `keyvault_secrets`).
- **VM:** `/opt/homelab/data` bind mounts, `/opt/homelab/docker_stacks` git checkout, rendered `/opt/homelab/docker_stacks/docker/.env`, systemd units (`cloudflared`, backups), container workloads.

## Data and secrets flow

1. Operator seeds **Azure Key Vault** (`vault-rg`).
2. `deploy-homelab.yml` loads secrets into Ansible facts (`vault_*`).
3. `docker_stacks_deploy` templates **`.env`** on the VM from those facts (not from committing `.env` to git).

## Networking (simplified)

- NSG allows SSH from `var.ssh_allowed_cidr`.
- Application access is typically via **Cloudflare Tunnel** (HTTPS to Cloudflare → tunnel → localhost ports on VM) and/or **Tailscale**.

## Design practices

- **Secrets:** Application and backup credentials are loaded at deploy time from Key Vault, not embedded in committed Compose env files.
- **Lifecycle:** With secrets in `vault-rg`, compute can be reprovisioned without losing centrally stored secrets.
- **Automation:** Ansible roles are intended to be reapplied safely; backup and restore scripts support recovery flows documented under `docker/`.
- **Exposure:** Baseline Linux OS hardening (no Windows targets in this repo), configurable SSH source restriction, tunnel-first exposure for web UIs, optional mesh access via Tailscale.
