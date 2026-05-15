# security_hardening role

This role provides opinionated, CIS-style **paranoid** security hardening for **Ubuntu Server** and other **Debian-family** hosts (`ansible_facts.os_family == Debian`). It matches the supported VM image in this repository (Ubuntu LTS on Azure).

It is structured to be modular by concern so that you can selectively apply or override behavior via variables and tags.

## Entry points

- `tasks/main.yml` — asserts Debian family, then includes `tasks/linux/main.yml`.

### Linux concerns

- `linux/os_baseline.yml` — package updates and basic OS state
- `linux/auth_access.yml` — SSH configuration (port, root login, password auth)
- `linux/network_firewall.yml` — UFW packages/services and SSH rules
- `linux/audit_logging.yml` — ensures `auditd` is present
- `linux/filesystem.yml` — basic filesystem permission sanity
- `linux/verify.yml` — SSH syntax and service-state verification

## Variables

Defined in `defaults/main.yml`:

- `security_hardening_profile` (default: `cis_paranoid`) — High-level intent flag reserved for future profile-specific tuning.

- `security_hardening_apply_network_firewall` (default: `true`) — Whether to manage host firewalls at all.

- `security_hardening_enable_auditd` (default: `true`) — Whether to ensure `auditd` is installed/enabled where available.

- `security_hardening_verify_only` (default: `false`) — When `true`, the role is intended to run verification checks only (you can gate mutating tasks on this variable).

### SSH (Linux)

- `security_hardening_ssh_port` (default: `22`) — SSH port; kept on 22 by default but can be moved to a non-standard port.

- `security_hardening_permit_root_login` (default: `"no"`) — Controls `PermitRootLogin` in `sshd_config`.

- `security_hardening_password_auth` (default: `"no"`) — Controls `PasswordAuthentication` in `sshd_config`.

## Tags

Key tag namespaces:

- `security` — all role tasks
- `security:linux` — Linux hardening
- `security:os_baseline`, `security:auth`, `security:network`, `security:audit`, `security:filesystem`, `security:services`, `security:verify`

Example:

```bash
ansible-playbook playbooks/deploy-homelab.yml -t security:linux,security:auth
```

## Usage

Example from a playbook:

```yaml
- name: Apply paranoid security hardening
  hosts: all
  become: true
  roles:
    - role: security_hardening
      tags: ['security']
```

Override defaults in inventory or group vars as needed, for example:

```yaml
security_hardening_ssh_port: 2222
```
