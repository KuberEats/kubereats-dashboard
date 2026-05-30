# Kubereats Dashboard

Monitoring-as-code for the Kubereats cloud-native food ordering system.

This first version focuses only on PostgreSQL database observability:

- Prometheus metrics collection
- Grafana dashboards provisioned from JSON
- Alertmanager-ready Prometheus rules
- `postgres_exporter` for PostgreSQL metrics
- optional Patroni and DB VM node exporter scrapes
- lightweight GCS backup freshness exporter

Backend service health checks, application `/metrics`, tracing, logging stacks, and frontend monitoring are intentionally out of scope for this version.

## Quick Start

```bash
cp .env.example .env
make up
```

Open:

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

Default local Grafana credentials come from `.env`. The example uses `admin` / `admin`; change them before sharing the stack.

## Configuration

Edit `.env` before using real infrastructure values:

- `PG_NODE_*_DSN`: PostgreSQL exporter connection strings
- `GCS_BACKUP_BUCKET` and `GCS_BACKUP_PREFIX`: backup location to check
- `GOOGLE_APPLICATION_CREDENTIALS`: path inside the exporter container when mounting credentials locally

Do not commit real passwords, service account JSON files, private IPs, or production hostnames.

Optional external scrape targets live in:

- `prometheus/file_sd/patroni.yml`
- `prometheus/file_sd/db-node-exporter.yml`

These files are templates with no active targets by default. Add real targets in your local environment or deployment system.

## Commands

```bash
make up        # start local Prometheus, Grafana, Alertmanager, exporters
make down      # stop the local stack
make logs      # follow local stack logs
make validate  # validate configs and dashboard JSON
```

## Documentation

See [docs/db-monitoring.md](docs/db-monitoring.md) for the monitoring model, dashboard guide, alert runbook notes, and future Kubernetes deployment path.
