#!/usr/bin/env bash
set -euo pipefail

required_files=(
  README.md
  Makefile
  .env.example
  deploy/gcp-vm/docker-compose.yml
  prometheus/prometheus.yml
  prometheus/rules/postgres-alerts.yml
  alertmanager/alertmanager.yml
  grafana/provisioning/datasources/prometheus.yml
  grafana/provisioning/datasources/google-cloud-monitoring.yml
  grafana/provisioning/datasources/kubernetes-prometheus.yml
  grafana/provisioning/dashboards/dashboards.yml
  grafana/dashboards/kubereats-postgres-overview.json
  grafana/dashboards/kubereats-postgres-ha.json
  grafana/dashboards/kubereats-backup-gcs.json
  grafana/dashboards/kubereats-gcp-load-balancer-overview.json
  grafana/dashboards/kubereats-gcp-vpn-router-overview.json
  grafana/dashboards/kubereats-k8s-cluster-overview.json
  grafana/dashboards/kubereats-k8s-node-overview.json
  grafana/dashboards/kubereats-k8s-workload-health.json
  grafana/dashboards/kubereats-argocd-overview.json
  grafana/dashboards/kubereats-platform-services.json
  grafana/dashboards/kubereats-merchant-service-metrics.json
  exporters/gcs-backup-exporter/exporter.py
  exporters/gcs-backup-exporter/Dockerfile
  exporters/gcs-backup-exporter/requirements.txt
  docs/db-monitoring.md
  docs/gcp-vm-quickstart.md
  docs/merchant-service-monitoring.md
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
python3 -m json.tool grafana/dashboards/kubereats-gcp-load-balancer-overview.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-gcp-vpn-router-overview.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-k8s-cluster-overview.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-k8s-node-overview.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-k8s-workload-health.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-argocd-overview.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-platform-services.json >/dev/null
python3 -m json.tool grafana/dashboards/kubereats-merchant-service-metrics.json >/dev/null

PROMETHEUS_IMAGE="${PROMETHEUS_IMAGE:-prom/prometheus:v2.55.1}"
PROMETHEUS_VOLUME="$(pwd)/prometheus:/etc/prometheus:ro"

run_promtool() {
  promtool check config prometheus/prometheus.yml
  promtool check rules prometheus/rules/postgres-alerts.yml
}

run_promtool_docker() {
  docker run --rm --entrypoint promtool -v "${PROMETHEUS_VOLUME}" "${PROMETHEUS_IMAGE}" \
    check config /etc/prometheus/prometheus.yml
  docker run --rm --entrypoint promtool -v "${PROMETHEUS_VOLUME}" "${PROMETHEUS_IMAGE}" \
    check rules /etc/prometheus/rules/postgres-alerts.yml
}

if command -v promtool >/dev/null 2>&1; then
  run_promtool
elif command -v docker >/dev/null 2>&1; then
  run_promtool_docker
else
  echo "promtool not found; JSON dashboards validated."
  echo "To validate Prometheus config with Docker:"
  echo "  docker run --rm --entrypoint promtool -v \"\$(pwd)/prometheus:/etc/prometheus:ro\" ${PROMETHEUS_IMAGE} check config /etc/prometheus/prometheus.yml"
  echo "  docker run --rm --entrypoint promtool -v \"\$(pwd)/prometheus:/etc/prometheus:ro\" ${PROMETHEUS_IMAGE} check rules /etc/prometheus/rules/postgres-alerts.yml"
fi

echo "validation complete"
