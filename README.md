# Kubereats Dashboard

Monitoring-as-code for Kubereats database, Kubernetes, backend autoscaling, and platform observability.

This repository is the source of truth for the first production-like monitoring stack on the GCP monitoring VM at `10.250.0.4`. The stack runs outside Kubernetes and covers database signals, Kubernetes signals, backend service metrics, autoscaling state, Prometheus alerting, and Grafana dashboards.

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
- `k8s-prometheus-federate-backend-autoscaling`
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
- [GCP Load Balancer, HA VPN, and Cloud Router monitoring](docs/gcp-lb-vpn-monitoring.md)
- [Kubernetes monitoring](docs/k8s-monitoring.md)
- [ArgoCD monitoring](docs/argocd-monitoring.md)
- [Platform services monitoring](docs/platform-services-monitoring.md)
- [Merchant Service monitoring](docs/merchant-service-monitoring.md)
- [Backend autoscaling monitoring](docs/backend-autoscaling-monitoring.md)
- [Private Grafana access](docs/private-grafana-access.md)

## Not Included Yet

- Loki or ELK logs
- OpenTelemetry tracing
- public Grafana exposure
- HA Grafana or remote metric storage
