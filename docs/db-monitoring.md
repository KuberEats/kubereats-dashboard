# Kubereats Database Monitoring

This repository currently focuses on database monitoring only. Kubereats depends on PostgreSQL for order, menu, and user data, so database availability, replication health, connection pressure, disk capacity, and backup freshness are the first operational signals to make visible.

Backend service health checks, application metrics, tracing, frontend telemetry, and log aggregation are future work. Keeping this first stack database-only makes it useful before backend services expose `/metrics`.

## Architecture

```mermaid
flowchart LR
  DB[(PostgreSQL HA nodes)] --> PE[postgres_exporter]
  DB --> PAT[Patroni /metrics optional]
  VM[DB VM OS] --> NE[node_exporter optional]
  GCS[(GCS backup bucket)] --> GBE[gcs-backup-exporter]
  PE --> PROM[Prometheus]
  PAT --> PROM
  NE --> PROM
  GBE --> PROM
  PROM --> GRAF[Grafana]
  PROM --> AM[Alertmanager]
```

## Components

- Prometheus scrapes exporters and evaluates database alert rules.
- `postgres_exporter` connects to PostgreSQL and exposes database metrics.
- Patroni metrics are optional and only work when the Patroni API exposes `/metrics`.
- `node_exporter` is optional and useful when database nodes are external VMs.
- `gcs-backup-exporter` checks the configured GCS bucket and prefix for the latest backup object.
- Grafana provisions the Prometheus datasource and dashboard JSON files automatically.
- Alertmanager is wired as the alert receiver, with notification routes left as a deployment-specific task.

## PostgreSQL Exporter User

Create a least-privilege monitoring user. Use a generated password from your secret manager, not the placeholder shown here.

```sql
CREATE USER postgres_exporter WITH PASSWORD 'CHANGE_ME';
GRANT pg_monitor TO postgres_exporter;
```

Use a DSN like:

```text
postgresql://postgres_exporter:CHANGE_ME@db-node-1.example.internal:5432/postgres?sslmode=require
```

For local lab environments, `sslmode=disable` can be acceptable. For production, prefer TLS.

## Run Locally

```bash
cp .env.example .env
make up
```

Open:

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000
- Alertmanager: http://localhost:9093

The example `.env` contains placeholders. `postgres_exporter` containers may start while PostgreSQL targets are unreachable until real DSNs are configured.

## Configure `.env`

Set:

- `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD`
- `KUBEREATS_ENV`
- `KUBEREATS_DB_CLUSTER`
- `PG_NODE_1_DSN`, `PG_NODE_2_DSN`, and `PG_NODE_3_DSN`
- `GCS_BACKUP_BUCKET`, `GCS_BACKUP_PREFIX`, and `GCS_BACKUP_MAX_AGE_HOURS`
- `GOOGLE_APPLICATION_CREDENTIALS` only when mounting a local credential file for the GCS exporter

Do not commit `.env`, service account keys, real database passwords, private IPs, or private hostnames.

Optional Patroni and node exporter targets are configured through Prometheus file service discovery:

- `prometheus/file_sd/patroni.yml`
- `prometheus/file_sd/db-node-exporter.yml`

These files are empty by default. In a real environment, generate or mount deployment-specific versions.

## Verify Prometheus Targets

In Prometheus, open **Status > Targets** and check:

- `postgres-exporter`: one target per configured DB node
- `patroni`: optional targets if file service discovery is populated
- `db-node-exporter`: optional targets if file service discovery is populated
- `gcs-backup-exporter`: backup freshness exporter

For config validation:

```bash
make validate
```

## Grafana Dashboards

Grafana loads dashboards from `grafana/dashboards` into the `Kubereats Database` folder.

`Kubereats PostgreSQL Overview` shows PostgreSQL up/down state, connection pressure, transaction rates, activity states, database size, locks, deadlocks, and exporter scrape status.

`Kubereats PostgreSQL HA` shows Patroni leader state when available, replication lag, WAL activity, primary/replica signals, failover-related changes, and node availability.

`Kubereats GCS Backup` shows latest backup age, freshness status, exporter success, object count under the backup prefix, latest observed object timestamp, and the 26-hour backup SLO.

## Alerts

### Alert KubereatsPostgresExporterDown

Prometheus cannot scrape `postgres_exporter`. Check the exporter container, network path, and DSN.

### Alert KubereatsPostgresDown

`postgres_exporter` is reachable, but PostgreSQL reports `pg_up=0`. Check PostgreSQL process health, credentials, port access, and host availability.

### Alert KubereatsPostgresConnectionsHigh

Connection usage is above 80 percent of `max_connections`. Check application connection pools, stuck sessions, and whether pool limits match database capacity.

### Alert KubereatsPostgresIdleInTransactionHigh

More than five sessions are idle in transaction. Identify sessions holding locks and review transaction handling.

### Alert KubereatsPostgresReplicationLagHigh

Replication lag is above 64 MiB. Check replica health, WAL receiver status, disk pressure, and network latency.

### Alert KubereatsPostgresDeadlocksDetected

Deadlocks increased recently. Review recent write paths and transaction ordering.

### Alert KubereatsPostgresDatabaseGrowthHigh

Projected growth is above 10 GiB per day. Check ingestion changes, indexes, table bloat, and retention.

### Alert KubereatsDbDiskUsageHigh

A database node filesystem is above 85 percent used. Check data volume, WAL volume, logs, and backup retention.

### Alert KubereatsPatroniNoLeader

No Patroni target reports itself as leader. Check Patroni API reachability, DCS health, and cluster election status.

### Alert KubereatsGcsBackupTooOld

The latest observed backup object is older than the configured max age. Check backup jobs, pgBackRest logs, GCS permissions, and object prefix.

### Alert KubereatsGcsBackupExporterFailed

The exporter process is running but its latest GCS check failed. Check ADC credentials, bucket name, prefix, and network access.

## Known Limitations

- External DB node discovery is template-based in this repo and should be generated or mounted per environment.
- Patroni metric names can vary by version; dashboard panels and alerts may need adjustment after target verification.
- PostgreSQL replication lag metric names can vary with exporter version and custom queries.
- Alertmanager notification receivers are intentionally placeholders.
- The local stack does not create PostgreSQL or Patroni nodes.

## Kubernetes-Ready Path

A later Kubernetes deployment should use:

- `kube-prometheus-stack`
- `ServiceMonitor` for in-cluster exporters
- `additionalScrapeConfigs` for external DB VMs
- Grafana dashboard ConfigMaps generated from `grafana/dashboards`
- Kubernetes Secrets, External Secrets, or Workload Identity for credentials

Do not store GCP service account keys in Git. Prefer Workload Identity on GKE when possible.

## Future Work

- backend `/metrics`
- application health checks
- Loki or ELK logs
- OpenTelemetry tracing
- Kubernetes `ServiceMonitor` integration
- Grafana MCP-assisted dashboard iteration
