# SELinux Strategy for Homelab Containers

## Problem Statement

When Podman mounts container volumes with the `:Z` flag (private labeling), SELinux automatically assigns MCS (Multi-Category Security) labels like `container_file_t:s0:c145,c979`. If multiple containers mount different paths with `:Z`, they get different MCS categories, causing:

- Containers cannot write to shared volumes
- Cross-container service dependencies fail  
- Unpredictable audit denials

**Root Cause**: No durable SELinux context management in Ansible before Podman starts containers.

## Solution

Apply a **single, consistent SELinux file context** to all homelab data directories **before** container deployment:

```bash
semanage fcontext -a -t container_file_t '/opt/homelab/data(/.*)?'
semanage fcontext -a -t container_file_t '/opt/homelab/media(/.*)?'
restorecon -Rv /opt/homelab/data /opt/homelab/media
```

This ensures:

1. **Durable labeling**: persists across `restorecon` calls via SELinux policy
2. **Consistent type**: all paths get `container_file_t` (the standard container data type)
3. **No MCS pre-assignment**: Podman applies MCS at runtime per mount, not conflicts
4. **Recovery-safe**: migration data inherits correct labels on restore

## Implementation

The `docker_directories` Ansible role now:

1. Detects if SELinux is Enforcing/Permissive/Disabled
2. Adds persistent file context rules via `community.general.sefcontext`
3. Applies rules with `restorecon -Rv` after each context addition
4. Exits gracefully if SELinux is disabled

### Affected Paths

- `/opt/homelab/data` (primary app data)
- `/opt/homelab/media` (media/library data)
- `/mnt/media` (external media mount point, if present)
- `/mnt/media_storage` (external storage mount point, if present)

## Bind Mount Rules

All app compose files use one of:

| Mount Pattern | Type | Reason |
|---|---|---|
| `/opt/homelab/data/appname:/data:Z` | Private relabel | Most app data; each app gets isolated MCS |
| `/opt/homelab/media:/media:z` | Shared relabel | Shared library mounts; apps can cowrite |
| `/var/run/docker.sock:/var/run/docker.sock:Z` | Private relabel | Socket passthrough to Portainer; private isolation |

### `:Z` vs `:z` vs no flag

- **`:Z` (private)**: Container gets unique MCS; best for app data isolation
- **`:z` (shared)**: Multiple containers share same MCS; needed for truly shared directories  
- **no flag**: Use host's current label (risky, denials likely)

## Verification

After running the role, verify labeling with:

```bash
ls -Zd /opt/homelab/data /opt/homelab/media
# Expected: system_u:object_r:container_file_t:s0 (without MCS categories)

# After containers start:
ls -Zd /opt/homelab/data
# Expected: system_u:object_r:container_file_t:s0:c###,c### (with MCS from Podman)
```

Monitor audit denials:

```bash
sudo ausearch -m avc -ts recent 2>/dev/null | grep "container_file_t" | head -10
```

If no denials appear, SELinux is satisfied.

## Known Limitations

1. **Community.general dependency**: Ansible `community.general` collection is required for `sefcontext` module. Install via:
   ```bash
   ansible-galaxy collection install community.general
   ```

2. **Rootful vs Rootless Podman**: This strategy works for both, but rootless Podman may have additional confinement. Test in target environment.

3. **External mounts**: If `/mnt/media` or `/mnt/media_storage` are NFS/SMB/external, the filesystem may not support SELinux labels. The Ansible role handles this gracefully by registering changes only if the `sefcontext` module succeeds.

## Debugging SELinux Issues

If containers still show SELinux denials after role runs:

1. Check Podman's confinement profile:
   ```bash
   podman run --security-opt label=disable alpine echo "OK"
   ```
   If this works, then SELinux is the issue.

2. Generate and apply a local policy module:
   ```bash
   sudo ausearch -m avc -ts recent -k "denied" | grep "comm=" | tail -50 > /tmp/denials.txt
   sudo audit2allow -a -M homelab_container_local
   sudo semodule -i homelab_container_local.pp
   ```

3. Check for MCS conflicts in audit:
   ```bash
   sudo ausearch -m avc -ts recent | grep "tcontext=.*c[0-9]*,c[0-9]*" | head -5
   ```

## Future Work

- Automate `audit2allow` module generation for non-standard denial patterns
- Add per-app SELinux profiles for stricter isolation
- Integrate with Kubernetes if migration happens (different labeling model)
