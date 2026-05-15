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
cd ../ansible && ansible-galaxy collection install -r requirements.yml
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml --syntax-check
```

CI runs Terraform fmt/validate and Ansible syntax checks on push and pull requests to `main` (using a placeholder inventory under `.github/`).
