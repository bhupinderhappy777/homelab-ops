# Operations guide

Authoritative runbook from an empty subscription to a running homelab: Terraform provisions compute; secrets live in Azure Key Vault (`vault-rg`); Ansible configures the VM, deploys Compose stacks, schedules backups, and installs the tunnel agent.

## Prerequisites

- Azure CLI (`az login`), Terraform, Ansible 2.14+
- SSH key pair; public key used for the VM admin user
- Git clone of this repo on your **control machine** (laptop or CI)

## 1. Terraform (Azure VM + network)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit: never commit tfvars
terraform init
terraform plan
terraform apply
```

See [terraform/README-tf.md](../terraform/README-tf.md) for variables, NSG/SSH, and disk size. Note the **public IP** output for inventory.

## 2. Ansible inventory

Create a local inventory file (gitignored) from the example:

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini
```

Edit `ansible/inventory/hosts.ini`:

```ini
[azure_vm]
<your-vm-public-ip> ansible_user=<your-admin-username>
```

`ansible_user` must match Terraform `admin_username`. Do not commit `hosts.ini` if it contains production addresses in a public repository.

## 3. Azure Key Vault (`vault-rg`)

Keep the vault in resource group **`vault-rg`** so `terraform destroy` on the compute stack does not delete secrets.

1. Create the vault (Portal, `az keyvault create`, or a small separate Terraform stack).
2. Grant your identity **Get / List / Set** on secrets as needed.
3. Export vault coordinates on the **Ansible control machine**:

```bash
export AZURE_KEY_VAULT_NAME='<your-vault-name>'
export AZURE_KEY_VAULT_URI="$(az keyvault show -g vault-rg -n "$AZURE_KEY_VAULT_NAME" --query properties.vaultUri -o tsv)"
```

## 4. Seed secrets (one-time)

Pick one:

**A. From a local YAML file** (keys must be `vault_*`; never commit the file):

```bash
cd /path/to/homelab-ops
ansible-galaxy collection install -r ansible/requirements.yml
export AZURE_KEY_VAULT_NAME='<your-vault-name>'
python3 ansible/scripts/import_vars_yaml_to_keyvault.py /path/to/local-secrets.yaml
```

**B. From `docker/.env`** (copy from [docker/.env.example](../docker/.env.example), fill values; file is gitignored):

```bash
export AZURE_KEY_VAULT_NAME='<your-vault-name>'
./ansible/scripts/seed_keyvault_hardcoded.example.sh
# or: ./ansible/scripts/seed_keyvault_hardcoded.example.sh /path/to/.env
```

Key name mapping: [ansible/roles/keyvault_secrets/defaults/main.yml](../ansible/roles/keyvault_secrets/defaults/main.yml).

## 5. Deploy the homelab

```bash
cd ansible
ANSIBLE_CONFIG=./ansible.cfg ansible-galaxy collection install -r requirements.yml
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  --skip-tags migration_restore,backup_restore
```

**Restore from OCI on first boot** (after Key Vault is populated and `restic` env secrets exist):

```bash
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  -e backup_restore_snapshot=latest
```

**One-time migration import** (mutually exclusive with snapshot restore in the same run):

```bash
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  -e migration_restore_archive_dir=/path/to/export
```

Common Ansible tags on `deploy-homelab.yml`: `keyvault`, `security`, `base`, `docker`, `directories`, `stacks`, `backup`, `backup_restore`, `tunnel`, `tailscale`. The `chezmoi` tag applies to [server.yml](../ansible/playbooks/server.yml), not the homelab VM deploy playbook.

## 6. Cloudflare Tunnel

Create the tunnel and routes in Cloudflare Zero Trust. Ansible installs `cloudflared` and a systemd unit using `vault_cloudflare_tunnel_token` from Key Vault. Route public hostnames to the ports published on the VM (see [docker/DEPLOYMENT.md](../docker/DEPLOYMENT.md#cloudflare-tunnel)).

## 7. Backups and restore

- Strategy and retention: [docker/BACKUP_STRATEGY.md](../docker/BACKUP_STRATEGY.md)
- Scripts on the host (after deploy): `/opt/homelab/docker_stacks/docker/scripts/backup.sh`, `restore.sh`
- Manual backup example: `sudo CONTAINER_RUNTIME=docker /opt/homelab/docker_stacks/docker/scripts/backup.sh`

## 8. Dotfiles (optional, not the VM deploy playbook)

[ansible/playbooks/server.yml](../ansible/playbooks/server.yml) applies [chezmoi](../ansible/roles/chezmoi) using `dotfiles_repo` from [ansible/vars/homelab_public.yml](../ansible/vars/homelab_public.yml). Use `--skip-tags chezmoi` if unused.

## Further reading

| Topic | Doc |
|--------|-----|
| Repo layout | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Deep deploy / migration paths | [docker/DEPLOYMENT.md](../docker/DEPLOYMENT.md) |
| Adding a stack | [docker/ADDING_SERVICE.md](../docker/ADDING_SERVICE.md) |
| Ansible details | [ansible/README-ansible.md](../ansible/README-ansible.md) |
| Security | [SECURITY.md](../SECURITY.md) |

## Replacing Git history on the remote

If you created a **new root commit** (no prior history) and need to overwrite `origin/main`:

```bash
git push --force-with-lease origin main
```

Everyone with an old clone must **fetch reset** or **re-clone**. Rotate any credential that might have existed in old commits.
