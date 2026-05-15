# Monitoring stack validation (Docker)

## Overview

The unified monitoring stack includes:

- **Prometheus**: Metrics collection and alerting (scrapes all services)
- **Grafana**: Visualization and dashboarding
- **Loki**: Log aggregation
- **Promtail**: Log shipper with Docker service discovery
- **cAdvisor**: Container metrics (expects Docker Engine)
- **node-exporter**: Host system metrics

## Bring up the stack

On the VM (or with paths adjusted on a dev host):

```bash
docker compose -f docker/stacks/monitoring/compose.yml up -d
```

Ensure `CONTAINER_SOCKET_PATH` in `docker/.env` points at the Docker socket (default `/var/run/docker.sock`).

## Pre-deployment checklist

- [ ] `/opt/homelab/data` and stack subdirectories exist with expected ownership after Ansible (`docker_directories` role)
- [ ] External networks exist (couchdb, docuseal, firefly, immich, jellyfin, monica, n8n, paperless_*, pihole, portainer)
- [ ] `.env` has `CONTAINER_SOCKET_PATH` set correctly for Docker
- [ ] Prometheus and Grafana have sufficient disk for time-series retention (default 15 days)
- [ ] Memory allocation is available (~3.7GB across containers)

## Service checks

### Prometheus (9090)

```bash
curl -sS http://localhost:9090/-/healthy
curl -sS http://localhost:9090/api/v1/targets | jq .data.activeTargets[].labels
```

Expect scrape targets **UP** where the application and `node-exporter` are running. cAdvisor can be down if the profile is disabled or the socket is wrong; fix the Docker socket path first.

### Grafana (3005)

```bash
curl -sS http://localhost:3005/api/health
```

### Loki (3100)

```bash
curl -sS http://localhost:3100/ready
```

### Promtail

```bash
docker logs -f "$(docker ps -q -f name=monitoring_promtail)" 2>&1 | head -50
```

Expect messages indicating Docker target discovery against `CONTAINER_SOCKET_PATH`.

### cAdvisor (8080)

```bash
curl -sS http://localhost:8080/api/v1/machine 2>&1 | head -20
```

### node-exporter (9100)

```bash
curl -sS http://localhost:9100/metrics | head -20
```

## Common issues

### External networks missing

Symptom: `network xyz not found`.

Fix: deploy application stacks first so Compose creates their networks, then monitoring:

```bash
for stack in docuseal firefly immich jellyfin monica n8n paperless_ngx pihole portainer; do
  docker compose -f docker/stacks/$stack/compose.yml up -d
done
docker compose -f docker/stacks/monitoring/compose.yml up -d
```

### Prometheus targets DOWN

Check the app container is running (`docker ps`), DNS names in Prometheus config resolve on the monitoring network, and `curl` to each `/metrics` URL from the Prometheus container.

## Post-deployment checklist

- [ ] Prometheus `/-/healthy` returns 200
- [ ] Grafana `/api/health` returns 200
- [ ] Loki `/ready` returns 200
- [ ] Promtail logs show container discovery
- [ ] Grafana shows data sources and dashboards

## Cleanup

```bash
docker compose -f docker/stacks/monitoring/compose.yml down
```

Persistent data under `/opt/homelab/data/prometheus`, `grafana`, `loki` remains until removed manually.

## References

- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- Loki: https://grafana.com/docs/loki/latest/
- Promtail Docker SD: https://grafana.com/docs/loki/latest/clients/promtail/scrape-configs/#docker
- cAdvisor: https://github.com/google/cadvisor
