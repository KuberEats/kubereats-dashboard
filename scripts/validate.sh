#!/usr/bin/env bash
set -euo pipefail

required_files=(
  README.md
  Makefile
  .env.example
  deploy/local/docker-compose.yml
  prometheus/prometheus.yml
  prometheus/rules/postgres-alerts.yml
  alertmanager/alertmanager.yml
  grafana/provisioning/datasources/prometheus.yml
  grafana/provisioning/dashboards/dashboards.yml
  grafana/dashboards/kubereats-postgres-overview.json
  grafana/dashboards/kubereats-postgres-ha.json
  grafana/dashboards/kubereats-backup-gcs.json
  exporters/gcs-backup-exporter/exporter.py
  exporters/gcs-backup-exporter/Dockerfile
  exporters/gcs-backup-exporter/requirements.txt
  docs/db-monitoring.md
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing required file: $file" >&2
    exit 1
  fi
done

python3 -m json.tool grafana/dashboards/kubereats-postgres-overview.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-postgres-ha.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-backup-gcs.json >/dev/null

if command -v promtool >/dev/null 2>&1; then
  promtool check config prometheus/prometheus.yml
  promtool check rules prometheus/rules/postgres-alerts.yml
else
  echo "promtool not found; JSON dashboards validated."
  echo "To validate Prometheus config with Docker:"
  echo "  docker run --rm -v \"\$(pwd)/prometheus:/etc/prometheus:ro\" prom/prometheus:v2.55.1 promtool check config /etc/prometheus/prometheus.yml"
  echo "  docker run --rm -v \"\$(pwd)/prometheus:/etc/prometheus:ro\" prom/prometheus:v2.55.1 promtool check rules /etc/prometheus/rules/postgres-alerts.yml"
fi

echo "validation complete"
