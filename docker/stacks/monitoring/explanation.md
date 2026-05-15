# Monitoring Stack

## Context

- **Location:** docker/stacks/monitoring
- **Compose file:** compose.yml
- **Data paths:**
  - /opt/homelab/data/prometheus/data
  - /opt/homelab/data/grafana/data
  - /opt/homelab/data/loki/data

## Overview

This stack runs Prometheus, Grafana, Loki, Promtail, and Node Exporter. cAdvisor is intentionally removed for now because it did not expose a stable metrics endpoint on the current Docker host. Config files live alongside the compose file:

- prometheus/prometheus.yml
- loki/loki-config.yml
- promtail/promtail-config.yml
- grafana/provisioning/

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/monitoring/compose.yml up -d
```

## Access

- **Prometheus:** http://<node-ip>:9090
- **Grafana:** http://<node-ip>:3005

## Notes

- Prometheus joins multiple stack networks so it can scrape internal targets.
- Use GRAFANA_PASSWORD from docker/.env for the Grafana admin account.
- Loki log data is collected from Docker json-file logs via Promtail.

## Production Notes

- cAdvisor is intentionally removed for now because it did not expose a stable metrics endpoint on the current host.
- Promtail ships Docker logs to Loki with `job`, `stack`, `project`, `service`, and `container` labels.
