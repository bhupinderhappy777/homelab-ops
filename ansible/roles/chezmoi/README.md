# Chezmoi Role

This role manages user dotfiles using chezmoi, a dotfile management tool that allows you to store your configuration in git and deploy them to your home directory.

## Requirements

- Ansible 2.9 or higher
- Target systems running Linux or macOS
- Git installed on target systems

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# User for chezmoi operations
chezmoi_user: "{{ ansible_user_id }}"

# Home directory for dotfiles
chezmoi_home: "{{ lookup('env', 'HOME') }}"

# Git repository URL for dotfiles
chezmoi_repo: "{{ clone_dotfiles_repo | default('') }}"

# Git branch to use
chezmoi_branch: "{{ clone_dotfiles_branch | default('main') }}"

# Directory for chezmoi source state
chezmoi_source_path: "{{ chezmoi_home }}/.local/share/chezmoi"

# Install chezmoi binary
chezmoi_install_package: true

# Force apply all dotfiles
chezmoi_force_apply: false

# Reinitialize from repository
chezmoi_force_source_init: false

# Fix systemd unit ownership
chezmoi_fix_systemd_ownership: false

# Patch plasma scripts
chezmoi_patch_plasma_scripts: false
```

## Dependencies

**Required vault variable:**
```yaml
github_ssh_private_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  <encrypted SSH private key>
```

## Example Playbook

```yaml
---
- hosts: all
  vars:
    dotfiles_repo: "git@github.com:user/dotfiles.git"
    dotfiles_branch: "main"
  vars_files:
    - vars/secrets.yml
  roles:
    - chezmoi
```

## Tasks

1. **SSH Setup**: Deploys GitHub SSH private key for private repo access
2. **Config Purging**: Removes existing config files to allow managed config
3. **Chezmoi Install**: Installs chezmoi binary via official script
4. **Repository Init**: Initializes dotfiles from git repository
5. **Plasma Patches**: Patches KDE Plasma layout scripts (optional)
6. **Dotfile Apply**: Applies managed dotfiles to home directory
7. **Systemd Services**: Enables user systemd services for wallpaper, inbox watcher

## Managed Configurations

The role manages these dotfiles and configs:
- Shell configs: `.zshrc`, `.gitconfig`
- KDE configs: `kwinrc`, `kglobalshortcutsrc`, `konsolerc`, etc.
- App configs: VSCode, Audacity, Double Commander

## User Systemd Services

The role enables these systemd user services:
- `wallpaper-refresh.timer` - Periodic wallpaper refresh
- `inbox-watcher.service` - Inbox file monitoring

## Post-Installation

1. Restart shell for new configs to take effect
2. Log out/in for systemd service changes
3. Configure chezmoi interactively:
   ```bash
   chezmoi edit ~/.zshrc
   chezmoi apply
   ```

## Tags

- `chezmoi`: All chezmoi tasks
- `cli`: CLI-only tasks
- `gui`: GUI-related tasks
- `systemd`: Systemd service management

## License

MIT

## Author Information

Infrastructure Team
