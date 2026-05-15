# security_hardening role

This role provides opinionated, CIS-style **paranoid** security hardening for:

- Linux: Red Hat family (RHEL/Alma/Rocky) and Debian/Ubuntu
- Windows: Standalone Windows Server 2019/2022 and Windows 10/11

It is structured to be modular by concern and OS family so that you can
selectively apply or override behavior via variables and tags.

## Entry points

- `tasks/main.yml` – detects OS and dispatches to:
  - `tasks/linux/main.yml` for `RedHat` and `Debian` families
  - `tasks/windows/main.yml` for `Windows` / `Win32NT`

### Linux concerns

- `linux/os_baseline.yml` – package updates and basic OS state
- `linux/auth_access.yml` – SSH configuration (port, root login, password auth)
- `linux/network_firewall.yml` – firewall packages/services and SSH rules
- `linux/audit_logging.yml` – ensures `auditd` is present
- `linux/filesystem.yml` – basic filesystem permission sanity
- `linux/verify.yml` – SSH syntax and service-state verification

### Windows concerns

- `windows/os_baseline.yml` – basic services and security updates
- `windows/auth_access.yml` – password and lockout policy, optional RDP NLA
- `windows/network_firewall.yml` – Windows Firewall and allowed inbound ports
- `windows/audit_logging.yml` – core security audit categories
- `windows/secure_services.yml` – disabling legacy/insecure services and RDP (by default)
- `windows/verify.yml` – firewall and RDP state verification

## Variables

Defined in `defaults/main.yml`:

- `security_hardening_profile` (default: `cis_paranoid`)\n  High-level intent flag reserved for future profile-specific tuning.

- `security_hardening_apply_network_firewall` (default: `true`)\n  Whether to manage host firewalls at all.

- `security_hardening_enable_auditd` (default: `true`)\n  Whether to ensure `auditd` is installed/enabled on Linux where available.

- `security_hardening_verify_only` (default: `false`)\n  When `true`, the role is intended to run verification checks only (you can\n  gate mutating tasks on this variable).

### Linux-specific

- `security_hardening_ssh_port` (default: `22`)\n  SSH port; kept on 22 by default but can be moved to a non-standard port.

- `security_hardening_permit_root_login` (default: `"no"`)\n  Controls `PermitRootLogin` in `sshd_config`.

- `security_hardening_password_auth` (default: `"no"`)\n  Controls `PasswordAuthentication` in `sshd_config`.

### Windows-specific

- `security_hardening_windows_rdp_enabled` (default: `false`)\n  Whether RDP should be enabled; when `false` the role disables the RDP service.

- `security_hardening_windows_allowed_ports` (default: `[5985, 5986]`)\n  List of TCP ports that should be allowed inbound through Windows Firewall for\n  management (e.g. WinRM HTTP/HTTPS).

## Tags

Key tag namespaces:

- `security` – all role tasks
- `security:linux` / `security:windows` – OS-specific groupings
- `security:os_baseline`, `security:auth`, `security:network`, `security:audit`, `security:filesystem`, `security:services`, `security:verify`

These allow you to run only parts of the hardening, for example:

```bash
ansible-playbook playbooks/security-hardening.yml -t security:linux,security:auth
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
security_hardening_windows_rdp_enabled: true
security_hardening_windows_allowed_ports:
  - 5985
  - 5986
  - 3389
```
