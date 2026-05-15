# Tailscale Role

This Ansible role installs and configures Tailscale VPN on Linux systems, enabling secure mesh networking across your infrastructure.

## Requirements

- Ansible 2.9 or higher
- Target systems running **Ubuntu Server** (or Debian with equivalent packages)
- A Tailscale account with an authentication key

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# Additional arguments to pass to 'tailscale up' command
tailscale_args: ""

# Whether to automatically connect to Tailscale network
tailscale_up: true
```

### Required Variables (from vault)

```yaml
# Tailscale authentication key (from Tailscale admin console)
tailscale_auth_key: "tskey-auth-xxxxx..."
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
    - role: tailscale
      vars:
        tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
```

## Tasks

### Install Tasks

1. **Debian/Ubuntu**: Adds Tailscale GPG key, APT repository, installs `tailscale`, starts `tailscaled`

### Configure Tasks

1. **Status Check**: Checks current Tailscale connection status
2. **Connection**: Connects to Tailscale using auth key
3. **Display Info**: Shows Tailscale IP address on connection

## Usage Examples

### Basic Installation

```yaml
- hosts: all
  become: true
  roles:
    - tailscale
```

### With Authentication Key

```yaml
- hosts: all
  become: true
  vars_files:
    - vars/secrets.yml
  roles:
    - role: tailscale
      vars:
        tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
```

### As an Exit Node

```yaml
- hosts: exit_node
  become: true
  roles:
    - role: tailscale
      vars:
        tailscale_auth_key: "tskey-auth-xxxxx"
        tailscale_args: "--advertise-exit-node"
```

### With Subnet Routes

```yaml
- hosts: routers
  become: true
  roles:
    - role: tailscale
      vars:
        tailscale_auth_key: "tskey-auth-xxxxx"
        tailscale_args: "--advertise-routes=10.0.0.0/24,192.168.1.0/24"
```

## Tailscale Features

### Authentication
Uses auth key for automated, non-interactive connection.

### Network Routes
- `--advertise-routes`: Advertise subnet routes to other Tailscale nodes
- `--accept-routes`: Accept routes from other nodes

### Exit Node
- `--advertise-exit-node`: Offer to be an exit node for internet traffic

### Additional Options
See `tailscale_args` variable for custom options like:
- `--ssh`: Enable SSH
- `-- Operator`: Set operator user

## Firewall Configuration

The role ensures `tailscaled` service is allowed through firewall. Ensure your firewall rules permit:
- **Outbound**: UDP 41641 (WireGuard)
- **Outbound**: TCP 7844 (Cloudflare Tunnel)

## Verifying Connection

```bash
# Check status
tailscale status

# Get Tailscale IP
tailscale ip -4

# Test connectivity to another node
tailscale ping <peer-name>
```

## Troubleshooting

### Connection Issues

1. Verify auth key is valid
2. Check network connectivity:
   ```bash
   curl https://login.tailscale.com/api/status
   ```
3. Check service status:
   ```bash
   systemctl status tailscaled
   ```

### Auth Key Not Working

1. Generate new auth key in Tailscale admin console
2. Update vault with new key
3. Re-run playbook

## Tags

- `tailscale`: All Tailscale tasks

## License

MIT

## Author Information

Infrastructure Team
