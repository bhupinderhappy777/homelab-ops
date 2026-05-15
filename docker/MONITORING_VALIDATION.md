# Monitoring Stack Validation for Podman

## Overview

The unified monitoring stack includes:
- **Prometheus**: Metrics collection and alerting (scrapes all services)
- **Grafana**: Visualization and dashboarding
- **Loki**: Log aggregation (compatible with both Docker and Podman)
- **Promtail**: Log shipper with Docker/Podman service discovery
- **cAdvisor**: Container metrics (Docker-specific, limited Podman support)
- **node-exporter**: Host system metrics

## Runtime Requirements

### Docker (Standard)
```bash
docker compose -f docker/stacks/monitoring/compose.yml up -d
```

### Podman (Recommended for SELinux)
```bash
# Ensure CONTAINER_SOCKET_PATH in .env points to Podman socket
export CONTAINER_SOCKET_PATH=/run/user/1000/podman/podman.sock  # rootless
# OR
export CONTAINER_SOCKET_PATH=/run/podman/podman.sock  # rootful

podman-compose -f docker/stacks/monitoring/compose.yml up -d
```

## Pre-Deployment Checklist

- [ ] SELinux labels applied to `/opt/homelab/data` (via `ansible/roles/docker_directories`)
- [ ] External networks exist (couchdb, docuseal, firefly, immich, jellyfin, monica, n8n, paperless_*, pihole, portainer)
- [ ] `.env` file has `CONTAINER_SOCKET_PATH` set correctly
- [ ] Prometheus and Grafana have sufficient disk for time-series retention (default 15 days)
- [ ] Memory allocation is available (~3.7GB across containers)

## Service Validation Tests

### 1. Prometheus
**Port**: 9090  
**Health check**: `wget http://localhost:9090/-/healthy`

```bash
# Should show "Prometheus is Healthy."
curl http://localhost:9090/-/healthy

# Check targets (should show all app targets)
curl http://localhost:9090/api/v1/targets | jq .data.activeTargets[].labels
```

**Expected**: All scrape targets should be `UP` except cAdvisor (Podman limitation).

### 2. Grafana
**Port**: 3005  
**Default login**: admin / <value in GRAFANA_PASSWORD>

```bash
# Health check
curl http://localhost:3005/api/health

# Check datasources
curl http://localhost:3005/api/datasources \
  -H "Authorization: Bearer <grafana_token>"
```

**Expected**: Loki and Prometheus datasources should be healthy.

### 3. Loki
**Port**: 3100  
**Health check**: `wget http://localhost:3100/ready`

```bash
# Check ingestion status
curl http://localhost:3100/ready
```

**Expected**: Returns 200 OK with `"Ready"` or similar.

### 4. Promtail
**Port**: 9080  
**Function**: Ships container and host logs to Loki

```bash
# Check target discovery (Podman-specific)
podman logs -f monitoring_promtail_1 2>&1 | grep -i "docker\|podman\|found"

# Verify socket discovery works:
# Should see messages like "discovered 15 targets"
```

**Expected**: Promtail successfully discovers containers via socket.

**Troubleshooting Podman socket issues**:
- If Promtail fails with "connection refused", verify socket path:
  ```bash
  ls -la /run/podman/podman.sock          # rootful Podman
  ls -la /run/user/1000/podman/podman.sock # rootless
  ```
- Verify socket permissions:
  ```bash
  # Should be readable by container's UID (likely 0 or 1002)
  stat /run/podman/podman.sock
  ```

### 5. cAdvisor (Docker-specific)
**Port**: 8080  
**Limitation**: cAdvisor is designed for Docker, not Podman

```bash
# Test container metrics endpoint
curl http://localhost:8080/api/v1/machine 2>&1 | head -20
```

**Expected behavior**:
- **Docker**: Full container metrics available
- **Podman**: May show partial metrics or fail gracefully (expected)

**Podman workaround**:
If cAdvisor is non-functional on Podman:
1. Container metrics come from Prometheus' node-exporter (sufficient for most use cases)
2. For detailed container metrics, use `podman stats` directly or migrate to Prometheus cgroup metrics exporter
3. Consider disabling cAdvisor profile on Podman-only hosts

### 6. node-exporter
**Port**: 9100  
**Function**: System-level metrics (CPU, memory, disk, network)

```bash
curl http://localhost:9100/metrics | head -20
```

**Expected**: Returns Prometheus-format metrics for system components.

## Full Stack Integration Test

Run this once all individual services are healthy:

```bash
#!/bin/bash
set -e

echo "=== Monitoring Stack Integration Test ==="

# Prometheus scrape targets
echo "[1] Checking Prometheus targets..."
TARGETS=$(curl -s http://localhost:9090/api/v1/targets)
ACTIVE=$(echo "$TARGETS" | jq '.data.activeTargets | length')
INACTIVE=$(echo "$TARGETS" | jq '.data.inactiveTargets | length')
echo "  Active targets: $ACTIVE"
echo "  Inactive targets: $INACTIVE"

# Grafana datasources
echo "[2] Checking Grafana datasources..."
curl -s http://localhost:3005/api/datasources | jq '.[] | {name: .name, type: .type, isDefault: .isDefault}'

# Loki ingestion
echo "[3] Checking Loki ingestion..."
LABELS=$(curl -s http://localhost:3100/loki/api/v1/labels)
echo "  Available log labels: $(echo "$LABELS" | jq '.data | length') types"

# Node exporter query
echo "[4] Testing Prometheus query (node-exporter)..."
QUERY=$(curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes')
echo "  Sample query result: $(echo "$QUERY" | jq '.data.result[0].value')"

echo ""
echo "✓ All checks completed. See Grafana at http://localhost:3005"
```

## Known Issues & Workarounds

### Issue 1: Promtail Docker SD fails on Podman
**Symptom**: Promtail logs show "cannot connect to socket"  
**Cause**: Wrong socket path or permission denied  
**Fix**:
1. Verify socket path in `.env`: `CONTAINER_SOCKET_PATH`
2. Check socket permissions: `stat /run/podman/podman.sock`
3. If rootless, verify user owns the socket

### Issue 2: cAdvisor fails on Podman
**Symptom**: cAdvisor crashes with "cannot stat /var/lib/docker"  
**Cause**: cAdvisor expects Docker directory layout  
**Fix**:
1. Accept as known limitation (cAdvisor is Docker-only)
2. Disable cAdvisor profile on Podman: add `profiles: ["docker-only"]` to cAdvisor service
3. Deploy only on Docker hosts, or use `docker compose --profile docker-only up -d`

### Issue 3: External networks don't exist
**Symptom**: Docker/Podman error "network xyz not found"  
**Cause**: Application stacks (docuseal, immich, etc.) haven't created networks yet  
**Fix**: Deploy application stacks first:
```bash
for stack in docuseal firefly immich jellyfin monica n8n paperless_ngx pihole portainer; do
  podman-compose -f docker/stacks/$stack/compose.yml up -d
done
# Then deploy monitoring
podman-compose -f docker/stacks/monitoring/compose.yml up -d
```

### Issue 4: Prometheus targets show "DOWN"
**Symptom**: Targets marked as `DOWN` (except expected ones)  
**Cause**: Application not running or scrape endpoint blocked  
**Fix**:
1. Check if target service is running: `podman ps | grep <service>`
2. Verify scrape config in prometheus.yml (target address must be DNS resolvable in compose network)
3. Test manually: `curl http://<service>:<port>/metrics`

### Issue 5: High memory usage
**Symptom**: OOMKilled containers  
**Cause**: Time-series retention or Grafana dashboard queries too aggressive  
**Fix**:
1. Lower Prometheus retention: `--storage.tsdb.retention.time=7d` (in compose.yml)
2. Check Grafana query performance (reduce graph resolution)
3. Increase host RAM or add swap

## Verification Checklist (Post-Deployment)

- [ ] Prometheus: `curl http://localhost:9090/-/healthy` returns 200
- [ ] Grafana: `curl http://localhost:3005/api/health` returns 200
- [ ] Loki: `curl http://localhost:3100/ready` returns 200
- [ ] Promtail logs show container discovery (check `podman logs monitoring_promtail_1`)
- [ ] Grafana dashboard shows metrics (visit http://localhost:3005)
- [ ] No cAdvisor errors on Podman (expected on pure Podman systems)
- [ ] Application metrics appear in Prometheus targets

## Ansible Integration

The monitoring stack is deployed by `ansible/roles/docker_stacks_deploy/tasks/main.yml` with proper ordering:

```yaml
deploy_stacks:
  - monitoring  # Must be early for infrastructure observability
```

To re-run monitoring stack deployment:
```bash
ansible-playbook -i ansible/inventory/hosts.ini \
  ansible/playbooks/deploy-homelab.yml \
  -e 'docker_stacks_to_deploy=[monitoring]'
```

## Cleanup

To remove the monitoring stack:
```bash
podman-compose -f docker/stacks/monitoring/compose.yml down
# Persistent data in /opt/homelab/data/prometheus, /opt/homelab/data/grafana, /opt/homelab/data/loki remains
```

To remove persistent data:
```bash
sudo rm -rf /opt/homelab/data/{prometheus,grafana,loki}
```

## References

- Prometheus docs: https://prometheus.io/docs/
- Grafana docs: https://grafana.com/docs/
- Loki docs: https://grafana.com/docs/loki/latest/
- Promtail Docker SD: https://grafana.com/docs/loki/latest/clients/promtail/scrape-configs/#docker
- cAdvisor: https://github.com/google/cadvisor (Docker-focused)
- Podman socket paths: https://docs.podman.io/en/latest/markdown/podman.1.html#socket-activation
