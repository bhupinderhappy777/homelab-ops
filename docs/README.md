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

Ansible loads `vault_*` facts from Key Vault using the name mapping in [ansible/roles/keyvault_secrets/defaults/main.yml](../ansible/roles/keyvault_secrets/defaults/main.yml). Create each secret under **`vault-rg`** with the **hyphenated** names that file documents (they correspond to `vault_*` variables in play scope).

Example:

```bash
export AZURE_KEY_VAULT_NAME='<your-vault-name>'
az keyvault secret set --vault-name "$AZURE_KEY_VAULT_NAME" --name "grafana-password" --value "$(openssl rand -hex 16)"
```

Repeat for every secret your stacks require. For many keys at once, use your own private loop or script locally—**never** commit plaintext secrets or seed files.

## 5. Deploy the homelab

```bash
cd ansible
ANSIBLE_CONFIG=./ansible.cfg ansible-galaxy collection install -r requirements.yml
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  --skip-tags backup_restore
```

**Restore from OCI on first boot** (after Key Vault is populated and `restic` env secrets exist):

```bash
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml \
  -e backup_restore_snapshot=latest
```

Common Ansible tags on `deploy-homelab.yml`: `keyvault`, `security`, `base`, `docker`, `directories`, `stacks`, `backup`, `backup_restore`, `tunnel`, `tailscale`.

## 6. Cloudflare Tunnel

Create the tunnel and routes in Cloudflare Zero Trust. Ansible installs `cloudflared` and a systemd unit using `vault_cloudflare_tunnel_token` from Key Vault. Route public hostnames to the ports published on the VM (see [docker/DEPLOYMENT.md](../docker/DEPLOYMENT.md#cloudflare-tunnel)).

## 7. Backups and restore

- Strategy and retention: [docker/BACKUP_STRATEGY.md](../docker/BACKUP_STRATEGY.md)
- Scripts on the host (after deploy): `/opt/homelab/docker_stacks/docker/scripts/backup.sh`, `restore.sh`
- Manual backup example: `sudo /opt/homelab/docker_stacks/docker/scripts/backup.sh`

## Further reading

| Topic | Doc |
|--------|-----|
| Repo layout | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Deep deploy and OCI restore | [docker/DEPLOYMENT.md](../docker/DEPLOYMENT.md) |
| Adding a stack | [docker/ADDING_SERVICE.md](../docker/ADDING_SERVICE.md) |
| Ansible details | [ansible/README-ansible.md](../ansible/README-ansible.md) |
| Security | [SECURITY.md](../SECURITY.md) |
