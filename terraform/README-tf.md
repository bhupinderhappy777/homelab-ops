# Terraform (Azure compute)

This directory provisions the **homelab VM**: resource group, VNet, subnet, NSG (SSH from `var.ssh_allowed_cidr`), public IP, NIC, and a **Linux spot VM** (Ubuntu 24.04). Optional Key Vault resources may exist for experimentation; production secrets should live in a vault under **`vault-rg`** (see [docs/README.md](../docs/README.md)).

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

Use the **public IP** (and `admin_username`) in `ansible/inventory/hosts.ini` (copy from [ansible/inventory/hosts.ini.example](../ansible/inventory/hosts.ini.example)).

## Operational notes

- **SKU / region:** if `terraform apply` fails on VM size, pick another `vm_size` or region; `az vm list-skus --location <region> --size <prefix> -o table` helps.
- **SSH:** the NSG allows TCP 22 from `ssh_allowed_cidr`; tighten this in production.
- **State:** keep `*.tfstate` out of git (see root `.gitignore`); use a remote backend for teams.

Next step: [docs/README.md](../docs/README.md) (Key Vault + Ansible).
