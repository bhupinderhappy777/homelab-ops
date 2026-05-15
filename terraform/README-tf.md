# Terraform (Azure compute)

This directory provisions the **homelab VM**: resource group, VNet, subnet, NSG (SSH from `var.ssh_allowed_cidr`), public IP, NIC, and a **Linux spot VM** (Ubuntu 24.04). **Key Vault is not created here**—use a vault in **`vault-rg`** (or elsewhere) for secrets Ansible reads (see [docs/README.md](../docs/README.md)). An older optional compute-scoped Key Vault module lives under [../archived/keyvault.tf](../archived/keyvault.tf) for reference only.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az login`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.2
- SSH public key material: set `ssh_public_key` or `ssh_public_key_path` in `terraform.tfvars` (never commit real `terraform.tfvars`)

## Quick start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init
terraform plan
terraform apply
```

Read [variables.tf](variables.tf) and [terraform.tfvars.example](terraform.tfvars.example) for `vm_size`, `os_disk_size_gb`, `location`, `ssh_allowed_cidr`, etc.

## Outputs

Use the **public IP** and **`admin_username` output** in `ansible/inventory/hosts.ini` (copy from [ansible/inventory/hosts.ini.example](../ansible/inventory/hosts.ini.example)); `ansible_user` must equal `admin_username` (default `deployuser`).

## Operational notes

- **SKU / region:** if `terraform apply` fails on VM size, pick another `vm_size` or region; `az vm list-skus --location <region> --size <prefix> -o table` helps.
- **SSH:** the NSG allows TCP 22 from `ssh_allowed_cidr`; tighten this in production. Azure installs your public key only for `admin_username`. Connect with the matching **private** key (same material as `ssh_public_key` / `ssh_public_key_path` in `terraform.tfvars`). Terraform may hide `admin_ssh_key` in plan output when the key variable is marked sensitive; that is expected.
- **State:** keep `*.tfstate` out of git (see root `.gitignore`); use a remote backend for teams.
Next step: [docs/README.md](../docs/README.md) (Key Vault + Ansible).
