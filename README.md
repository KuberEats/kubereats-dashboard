# Kubereats Dashboard

Monitoring-as-code for Kubereats database observability.

This repository is the source of truth for the first production-like monitoring stack on the GCP monitoring VM at `10.250.0.4`. The phase-1 stack runs outside Kubernetes and focuses on database signals: PostgreSQL exporter metrics, Patroni availability, DB node exporter metrics, GCS backup freshness, Prometheus alerting, and Grafana dashboards.

Backend application `/healthz`, backend `/metrics`, Kubernetes monitoring, tracing, and log aggregation are intentionally not included yet.

## Quick Start

```bash
cp .env.example .env
vim .env
make validate
make up
make ps
```

Open these from the monitoring VM or through an SSH tunnel:

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

Grafana credentials come from `.env`. Change `GRAFANA_ADMIN_PASSWORD` before using the stack beyond a throwaway lab.

## GCP VM Deployment

The VM deployment uses `deploy/gcp-vm/docker-compose.yml`. Prometheus, Grafana, Alertmanager, and the GCS backup exporter bind to localhost by default:

```text
127.0.0.1:3000
127.0.0.1:9090
127.0.0.1:9093
127.0.0.1:9817
```

Use an SSH tunnel instead of public `0.0.0.0` exposure:

```bash
ssh -J <jump-host-user>@<jump-host-public-ip> <monitor-user>@10.250.0.4 \
  -L 3000:127.0.0.1:3000 \
  -L 9090:127.0.0.1:9090 \
  -L 9093:127.0.0.1:9093
```

Then open Grafana, Prometheus, and Alertmanager on localhost.

## Configuration

`.env.example` contains placeholders only. Copy it to `.env` on the monitoring VM and fill runtime values there. Do not commit `.env`, database passwords, service account keys, or generated secrets.

Known lab DB nodes from `/home/edtsai/kubereats-IaC` are:

- `pg1`: `192.168.16.221`
- `pg2`: `192.168.16.222`
- `pg3`: `10.250.0.3`

Prometheus uses static scrape jobs for:

- `postgres-exporter`
- `patroni`
- `db-node-exporter`
- `gcs-backup-exporter`
- `prometheus`

The checked-in Prometheus config keeps valid placeholder targets. The GCP VM compose file rewrites those non-secret target values from `.env` when Prometheus starts, so environment-specific IPs stay out of Git.

## Commands

```bash
make up        # start Prometheus, Grafana, Alertmanager, and GCS exporter
make down      # stop the stack
make logs      # follow logs
make ps        # list service state
make restart   # restart services
make validate  # validate required files, dashboard JSON, and Prometheus config when promtool is available
```

## Documentation

- [GCP VM quickstart](docs/gcp-vm-quickstart.md)
- [Database monitoring design and runbook](docs/db-monitoring.md)

## Not Included Yet

- backend service `/healthz`
- backend service `/metrics`
- kube-prometheus-stack
- Loki or ELK logs
- OpenTelemetry tracing
- public Grafana exposure
- HA Grafana or remote metric storage
