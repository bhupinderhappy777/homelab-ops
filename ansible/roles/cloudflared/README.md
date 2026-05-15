# Cloudflared Role

This role installs the `cloudflared` binary and registers it as a systemd
service using a pre-created Cloudflare Tunnel token.

## Requirements

- Ansible 2.9 or higher
- Target systems running Ubuntu, Debian, RHEL, CentOS, or Fedora
- A Cloudflare Zero Trust tunnel already created in the dashboard

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# Cloudflare tunnel token (required). The main playbook also accepts the
# existing secret name `vault_cloudflare_tunnel_token`.
cloudflared_tunnel_token: ""

# Cloudflared version to install (latest = latest release)
cloudflared_version: latest

# Installation directory for cloudflared binary
cloudflared_install_dir: /usr/local/bin

# User and group for cloudflared service
cloudflared_user: root
cloudflared_group: root
```

## Dependencies

None.

## Example Playbook

```yaml
---
- hosts: servers
  become: true
  vars_files:
    - vars/secrets.yml
  roles:
    - role: cloudflared
```

## Usage Examples

### Basic Installation

```yaml
- hosts: all
  become: true
  vars_files:
    - vars/secrets.yml
  roles:
    - cloudflared
```

### With Vault-Encrypted Token

```yaml
- hosts: oci_nodes
  become: true
  vars_files:
    - vars/secrets.yml
  roles:
    - role: cloudflared
      vars:
        cloudflared_tunnel_token: "{{ cloudflared_tunnel_token }}"
```

## Setup Instructions

### 1. Create Tunnel in Cloudflare

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** > **Tunnels**
3. Click **Create a tunnel**
4. Select **Cloudflared** as the connector type
5. Name your tunnel (e.g., `oci-tunnel`)
6. Copy the generated tunnel token

### 2. Store Token in Ansible Vault

Encrypt your tunnel token:

```bash
ansible-vault encrypt_string 'YOUR_TUNNEL_TOKEN_HERE' --name cloudflared_tunnel_token
```

Add the output to `vars/secrets.yml`:

```yaml
cloudflared_tunnel_token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <encrypted output>
```

### 3. Run the Playbook

```bash
# Syntax check
ansible-playbook playbooks/server.yml --tags cloudflared --syntax-check

# Run on all OCI nodes
ansible-playbook playbooks/server.yml --tags cloudflared

# Run on specific host
ansible-playbook playbooks/server.yml --tags cloudflared -l ociubuntu
```

### 4. Verify

Check the Cloudflare Zero Trust dashboard - your tunnel should show as healthy.

## Managing Tunnel Configuration

Tunnel routing and ingress rules are managed in the Cloudflare dashboard
(Networks > Tunnels > your tunnel). This role deliberately does not render
local ingress YAML or manage hostnames from the repo.

To expose services:
1. Go to your tunnel in the Cloudflare dashboard
2. Add public hostname routes
3. Point to your internal services (e.g., `http://localhost:8080`)

## Troubleshooting

### Check cloudflared status

```bash
systemctl status cloudflared
cloudflared tunnel info
cloudflared logtail
```

### View logs

```bash
journalctl -u cloudflared -f
```

### Reinstall tunnel service

If credentials change, re-run the playbook with the new token.

## License

MIT

## Author Information

Infrastructure Team
