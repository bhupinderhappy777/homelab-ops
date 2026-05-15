#!/usr/bin/env bash
set -euo pipefail

# Downloads community Grafana dashboard JSON files used by the provisioning
# provider. Run once before the first deploy, or whenever you want to update
# the bundled dashboards.
#
# Usage:  ./monitoring/download-dashboards.sh

DIR="$(cd "$(dirname "$0")/grafana/provisioning/dashboards" && pwd)"

DASHBOARDS=(
  1860   # Node Exporter Full
  14282  # cAdvisor / Docker
  13639  # Loki / Promtail
)

for id in "${DASHBOARDS[@]}"; do
  echo -n "Downloading dashboard ${id}... "
  curl -sSf -o "${DIR}/${id}.json" \
    "https://grafana.com/api/dashboards/${id}/revisions/latest/download"
  echo "OK ($(wc -c < "${DIR}/${id}.json") bytes)"
done

echo "All dashboards saved to ${DIR}"
