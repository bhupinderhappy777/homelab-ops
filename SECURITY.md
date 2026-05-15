# Security

This repository is intended as a **template** for a personal homelab. Treat it like production code paths for **secrets** and **access**.

## Secrets and Git

- **Never commit** real credentials: use **Azure Key Vault** (recommended: resource group `vault-rg`) and gitignored files (`terraform.tfvars`, `docker/.env`, `ansible/vars/secrets.yml`, repo-root `secrets.yml`).
- If any secret was ever committed or pushed, **rotate it** everywhere it was used (Key Vault, cloud APIs, DB passwords, tunnel tokens, OCI keys, etc.). Removing files from a later commit does **not** erase them from old SHAs on remotes or forks.
- Enable [GitHub secret scanning](https://docs.github.com/en/code-security/secret-scanning) and **push protection** on the repository when possible.

## Fresh Git history

If this project was rewritten with a **new root commit** (no prior history), assume any old clone or fork still held historical material until deleted. Operators should still rotate credentials that might have been exposed before the rewrite.

## Terraform and SSH

- Restrict `ssh_allowed_cidr` in `terraform.tfvars` to your IP or a bastion range instead of `0.0.0.0/0` when practical.
- Protect Terraform **state** (remote backend, encryption); state can hold sensitive metadata.

## Reporting issues

If you find a **security issue in this public template** (not your private deployment values), open a [GitHub security advisory](https://docs.github.com/en/code-security/security-advisories) or contact the repository owner through their public profile. Do not file public issues with live credentials.
