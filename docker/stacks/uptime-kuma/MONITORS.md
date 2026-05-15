# Uptime Kuma — homelab monitors

Uptime Kuma stores monitors in its SQLite DB; there is no Compose field to declare checks. Keep a consistent list of HTTP targets and re-add them in the UI after rebuilds.

## Suggested targets

- External checks: your public hostnames (Cloudflare Tunnel) using `https://<hostname>`.
- Internal checks: service health endpoints on stack networks (e.g., `http://grafana:3000/api/health`).

## Add monitors in the UI

1. Open Kuma (see [explanation.md](./explanation.md) for access).
2. **Add New Monitor** → **HTTP(s)** for each hostname.
3. Add internal-only checks where useful (Grafana, Prometheus, Loki).

## Image

The stack uses `louislam/uptime-kuma:2.2.1` (pinned). `1.23.11` was never published on Docker Hub.
