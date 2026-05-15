# Pi-hole Stack

## Context

- **Location:** docker/stacks/pihole
- **Compose file:** compose.yml
- **Data paths:**
  - /opt/homelab/data/pihole_data/pihole
  - /opt/homelab/data/pihole_data/dnsmasq.d
- **Secret:** PIHOLE_PASSWORD in docker/.env

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/pihole/compose.yml up -d
```

## Access

- **DNS:** tcp/udp 53 on the host
- **Web UI:** http://<node-ip>:8082

## Notes

- Ensure no other process binds port 53 on the host.
- Admin password is from PIHOLE_PASSWORD.

## Production Notes

- DNS binds directly to host port `53/tcp` and `53/udp`.
- The admin UI is intentionally published on `8182`.
- Backup includes `/opt/homelab/data/pihole_data` through OCI restic snapshots.
