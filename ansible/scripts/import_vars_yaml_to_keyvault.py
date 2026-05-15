#!/usr/bin/env python3
"""One-time import: YAML vars with prefix vault_ -> Azure Key Vault secrets.

Secret names: strip vault_ and replace underscores with hyphens (matches role keyvault_secrets).

Usage:
  export AZURE_KEY_VAULT_NAME=myvault   # name only, not URI
  ./import_vars_yaml_to_keyvault.py /path/to/secrets.yml

Requires: PyYAML, Azure CLI logged in (az login) with rights to set secrets.
Does not print secret values.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

import yaml


def vault_key_to_secret_name(key: str) -> str | None:
    if not key.startswith("vault_"):
        return None
    body = key[len("vault_") :]
    name = body.replace("_", "-")
    if not re.match(r"^[a-zA-Z0-9-]{1,127}$", name):
        raise ValueError(f"Invalid derived secret name for key {key!r}: {name!r}")
    return name


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: import_vars_yaml_to_keyvault.py <vars.yaml>", file=sys.stderr)
        return 2
    vault_name = os.environ.get("AZURE_KEY_VAULT_NAME", "").strip()
    if not vault_name:
        print("error: set AZURE_KEY_VAULT_NAME to the Key Vault name", file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    if not isinstance(data, dict):
        print("error: YAML root must be a mapping", file=sys.stderr)
        return 2

    for key, value in data.items():
        secret = vault_key_to_secret_name(key)
        if secret is None:
            continue
        if value is None:
            continue
        val = str(value).strip()
        if val == "":
            continue
        subprocess.run(
            [
                "az",
                "keyvault",
                "secret",
                "set",
                "--vault-name",
                vault_name,
                "--name",
                secret,
                "--value",
                val,
                "--output",
                "none",
                "--only-show-errors",
            ],
            check=True,
        )
        print(f"set {secret}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
