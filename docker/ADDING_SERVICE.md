# Adding A New Service

This repo treats the repository as the source of truth. A new service is not
done when the compose file exists; it is only done when deploy, backup, and
restore paths are all accounted for.

## Workflow

1. Create a new stack directory under `docker/stacks/<service-name>/`.
2. Add `compose.yml`.
3. Add `explanation.md`.
4. Add any config files that the stack mounts from the repo.
5. Add required bind-mount directories to the Ansible directory role.
6. Add the stack to the Ansible deploy order.
7. Decide whether the stack should be included in backup and restore.
8. Test deploy syntax and the stack health locally or on the target host.

## 1. Compose File

Create `docker/stacks/<service-name>/compose.yml`.

Guidelines:

- Prefer pinned image versions for stateful apps.
- Use `/opt/homelab/data/...` for persistent bind mounts.
- Keep ports explicit.
- Add a healthcheck if the image supports one reliably.
- Use the shared `.env` variables only when the service truly needs them.

## 2. Explanation File

Create `docker/stacks/<service-name>/explanation.md` with:

- location
- compose file path
- host data paths
- access ports
- production notes
- backup/restore notes if special

## 3. Directory Creation In Ansible

Update:

- `ansible/roles/docker_directories/tasks/main.yml`

Add every bind-mounted host directory used by the new stack.

If the service requires a fixed UID/GID, set it there explicitly.

Examples:

- Paperless app data uses `1002:1002`
- Paperless Redis data uses `999:999`
- Monitoring data uses service-specific ownership

## 4. Add The Stack To Deployment

Update:

- `ansible/roles/docker_stacks_deploy/tasks/main.yml`

Add the stack to either:

- `homelab_light_stacks`
- `homelab_heavy_stacks`

Include the expected compose network name and compose network label.

Deploy order matters when a stack depends on external networks created by other
stacks.

## 5. Backup And Restore Decision

For every new service, decide one of these models:

1. File data only
2. Logical database dump plus selected file data
3. Excluded from automated restore because state is disposable or version-sensitive

Then update the scripts accordingly.

### If The Service Has Persistent Files

Review:

- `docker/scripts/backup.sh`
- `docker/scripts/restore.sh`

If the service data should be in OCI snapshots, make sure its paths are not
excluded.

### If The Service Has A Database Dump

Update the backup and restore scripts:

- `docker/scripts/backup.sh`
- `docker/scripts/restore.sh`

Add:

- container lookup prefix
- dump command
- restore command
- schema reset logic if PostgreSQL plain SQL is used

### If The Service Is Version-Sensitive Or Disposable

Document that clearly and exclude it from restore if necessary.

Current example:

- `portainer_data` is intentionally excluded from automated restore

## 6. Cloudflare Tunnel

If the service is public, configure the route in the Cloudflare dashboard.

This repo does not manage per-service public hostnames in local YAML anymore.
It only runs the `cloudflared` system service from the tunnel token.

The public hostname should route to the host-published local port.

## 7. Validation

At minimum run:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-homelab.yml --syntax-check
```

And validate the stack config if you changed compose files.

Examples:

```bash
docker compose -f docker/stacks/<service-name>/compose.yml config
```

On a target host, verify:

- container health
- local HTTP or TCP response
- backup impact if new persistent data was added

## 8. Update Docs

When a new service is added, update at least:

- `docker/README.md`
- `docker/DEPLOYMENT.md` if the workflow changes
- the stack `explanation.md`

If the backup or restore model changed, also update:

- `docker/BACKUP_STRATEGY.md`
