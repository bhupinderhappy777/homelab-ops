## Ansible setup

Operator walkthrough: **[docs/README.md](../docs/README.md)**.

Ansible is responsible for:

- loading secrets from **Azure Key Vault** into play scope (`keyvault_secrets` role)
- applying baseline hardening (`security_hardening`; Ubuntu / Debian family)
- installing **Docker Engine** (Compose plugin), `restic`, and OCI backup helpers
- creating `/opt/homelab` directories
- rendering `/opt/homelab/docker_stacks/docker/.env` from Key Vault–backed facts
- installing and configuring `cloudflared`
- deploying Compose stacks
- configuring nightly OCI backup cron
- optional **restic restore from OCI** when you pass `backup_restore_snapshot`

## Prerequisites

- Ansible 2.14+
- **`az` CLI** on the machine running Ansible (`az login`), used by the `keyvault_secrets` role to read secrets (no Python `azure.azcollection` lookup required for that role)
- `ansible-galaxy collection install -r requirements.yml` (optional for other Azure work; Key Vault reads use `az` only)
- `az login` on the control machine (used with `az keyvault secret show` for secrets).
- `export AZURE_KEY_VAULT_URI=...` for the vault in **`vault-rg`** (recommended), e.g.  
  `export AZURE_KEY_VAULT_URI="$(az keyvault show -g vault-rg -n "$AZURE_KEY_VAULT_NAME" --query properties.vaultUri -o tsv)"`  
  If you still manage a vault from the compute Terraform root, you can use `terraform output -raw key_vault_uri` instead.
- SSH access to the VM; for **SSH git clone** of this repo on the VM, `ansible.cfg` enables **agent forwarding** — load your GitHub key on the laptop first (`ssh-add -l`).

Non-secret defaults live in committed `vars/homelab_public.yml` (URLs, branch names, `admin_username`, etc.). Override via inventory `group_vars` or `-e` as needed.

## Inventory

Copy the example inventory, then edit it (this file is **gitignored**; do not commit real IPs in a public repo):

```bash
cp inventory/hosts.ini.example inventory/hosts.ini
```

[inventory/hosts.ini.example](inventory/hosts.ini.example):

```ini
[azure_vm]
<your-vm-public-ip> ansible_user=<your-admin-username>
```

`<your-admin-username>` must match the Terraform `admin_username` used when the VM was created.

## Secrets (Azure Key Vault in `vault-rg`)

All `vault_*` variables are read from Key Vault; name mapping is in [roles/keyvault_secrets/defaults/main.yml](roles/keyvault_secrets/defaults/main.yml).

**Full procedure:** [docs/README.md](../docs/README.md) (vault in `vault-rg`, exports, `az keyvault secret set`).

Quick reference from **repository root**:

```bash
export AZURE_KEY_VAULT_NAME='<your-vault-name>'
export AZURE_KEY_VAULT_URI="$(az keyvault show -g vault-rg -n "$AZURE_KEY_VAULT_NAME" --query properties.vaultUri -o tsv)"
az keyvault secret set --vault-name "$AZURE_KEY_VAULT_NAME" --name "grafana-password" --value "$(openssl rand -hex 16)"
```

Copy [docker/.env.example](../docker/.env.example) to `docker/.env` (gitignored) when you need the same variable names locally for Compose experiments; Ansible still sources secrets from Key Vault on the deploy path.

## Run the deploy

From `ansible/` so `ansible.cfg` is used:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml --skip-tags backup_restore
```

Restore from OCI backup:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  -e backup_restore_snapshot=latest
```
