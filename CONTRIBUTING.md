# Contributing

This repository is maintained as a personal homelab template. External contributions are welcome as issues or small pull requests.

## Guidelines

- **Never commit** credentials or environment-specific inventory: use Key Vault, gitignored `terraform.tfvars` / `docker/.env`, and `ansible/inventory/hosts.ini` (copy from `hosts.ini.example`). See [SECURITY.md](SECURITY.md).
- **Keep changes focused.** Prefer one logical change per pull request.
- **Match existing style.** Terraform formatted (`terraform fmt`), Ansible YAML two-space indent, shell scripts with `set -euo pipefail` where applicable.
- **Update documentation** when you change behavior operators rely on ([docs/README.md](docs/README.md), [README.md](README.md), or the relevant stack doc).

## Local checks (before opening a PR)

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini   # once; then edit IPs if needed
cd terraform && terraform fmt -recursive && terraform init -backend=false && terraform validate
# If you have no ~/.ssh/homelab_azure.pub and no ssh_public_key in tfvars, match CI:
# TF_VAR_ssh_public_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMVdMap2M8Jy8EjCnHqzNBCEU8xyFGW9LLHj9AgMrgW local-placeholder' terraform validate
cd ../ansible && ansible-galaxy collection install -r requirements.yml
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml --syntax-check
```

CI runs Terraform fmt/validate and Ansible syntax checks on push and pull requests to `main` (using a placeholder inventory under `.github/`).

### Why CI does not use `az login` or real SSH keys

- **Terraform:** `terraform validate` evaluates configuration including `local.admin_ssh_public_key` in `keyvault.tf`. GitHub-hosted runners do not have your `~/.ssh/homelab_azure.pub`. The workflow sets `TF_VAR_ssh_public_key` to a **syntactically valid placeholder** so `file(...)` is never used in CI. Your real key still comes from `terraform.tfvars` or env when you run Terraform locally or in a release pipeline.
- **Ansible:** `ansible-playbook --syntax-check` only checks playbook and role **syntax**. It does **not** execute tasks, so `keyvault_secrets` never runs and **Azure CLI is not invoked**. A full `ansible-playbook` run on a real host still needs `az login` (or a federated identity on the controller) and `AZURE_KEY_VAULT_URI`.

To add integration tests later (optional): use [Azure/login](https://github.com/Azure/login) with **OIDC** (preferred) or a **service principal** stored in GitHub encrypted secrets, scope credentials to read-only Key Vault access if possible, and run a constrained playbook (for example `--check` with a throwaway inventory) in a separate job.

## Cleaning local build caches

Avoid `git clean -fdX` at the repo root: it removes **all** gitignored *untracked* paths, including `ansible/inventory/hosts.ini`, `docker/.env`, `secrets.yml`, `terraform/terraform.tfvars`, and `terraform/*.tfstate*` if present.

To drop only disposable caches (safe):

```bash
rm -rf terraform/.terraform .ansible __pycache__
find . -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
```

Dry-run a broader clean while **keeping** operator-local files (requires Git 2.31+ for repeated `-e`):

```bash
git clean -fdXn \
  -e ansible/inventory/hosts.ini \
  -e docker/.env \
  -e secrets.yml \
  -e terraform/terraform.tfvars \
  -e 'terraform/terraform.tfstate*'
```

Remove `-n` after you confirm the list.
