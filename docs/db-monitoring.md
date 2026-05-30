# Kubereats Database Monitoring

This repository currently focuses on database monitoring only. Kubereats depends on PostgreSQL for order, menu, and user data, so database availability, replication health, connection pressure, disk capacity, and backup freshness are the first operational signals to make visible.

Backend service health checks, application metrics, tracing, frontend telemetry, and log aggregation are future work. Keeping this first stack database-only makes it useful before backend services expose `/metrics`.

The primary monitoring stack is designed to run outside the Kubernetes application cluster, preferably on an independent GCP VM named `gcp-monitor-01`. This keeps the monitoring plane out of the application cluster failure domain and separate from the PostgreSQL nodes it observes.

## Architecture

```mermaid
flowchart LR
  subgraph MON[gcp-monitor-01]
    PROM[Prometheus]
    GRAF[Grafana]
    AM[Alertmanager]
    GBE[gcs-backup-exporter]
  end
  subgraph ONPREM[On-prem or private network]
    DB[(PostgreSQL HA nodes)]
    PE[postgres_exporter]
    PAT[Patroni /metrics optional]
    NE[node_exporter optional]
  end
  GCPDB[(GCP PostgreSQL node private IP)] --> PROM
  DB --> PE
  DB --> PAT
  DB --> NE
  PE --> PROM[Prometheus]
  PAT --> PROM
  NE --> PROM
  GCS[(GCS backup bucket)] --> GBE
  GBE --> PROM
  PROM --> GRAF[Grafana]
  PROM --> AM[Alertmanager]
  GCM[Google Cloud Monitoring later] -. uptime checks .-> MON
```

## Components

- Prometheus scrapes exporters and evaluates database alert rules.
- `postgres_exporter` connects to PostgreSQL and exposes database metrics.
- Patroni metrics are optional and only work when the Patroni API exposes `/metrics`.
- `node_exporter` is optional and useful when database nodes are external VMs.
- `gcs-backup-exporter` checks the configured GCS bucket and prefix for the latest backup object.
- Grafana provisions the Prometheus datasource and dashboard JSON files automatically.
- Alertmanager is wired as the alert receiver, with notification routes left as a deployment-specific task.

The stack supports scraping PostgreSQL nodes over private network or VPN, scraping GCP-hosted PostgreSQL nodes by private IP, checking GCS backup freshness, and later integrating Google Cloud Monitoring for GCS, GCE, and uptime checks.

## Failure Domain Design

The primary Prometheus, Grafana, Alertmanager, and backup freshness exporter should run on `gcp-monitor-01`, outside the Kubernetes application cluster. This is intentional: if the Kubernetes cluster fails, the monitoring plane should still be able to show database state, backup freshness, and external node availability.

If the on-prem site fails, Prometheus on `gcp-monitor-01` should continue running and should show scrape failures, PostgreSQL unreachability, replication impact, or site-level alerts depending on which targets are unreachable. Alertmanager grouping by `cluster` and `site` helps collapse many related symptoms into a smaller incident view.

If Kubernetes fails, this database monitoring stack should remain available because it is not deployed inside the application cluster. Operators should still be able to open Grafana on `gcp-monitor-01`, inspect PostgreSQL status, and decide whether the database is healthy while application workloads are unavailable.

If the monitoring VM fails, Prometheus and Grafana from this stack are unavailable until the VM is recovered or restored. This is the main accepted risk in the first phase. Keep the VM simple, document restore steps, and back up configuration through Git. A later phase can add a standby monitoring VM or remote metric storage.

Google Cloud Monitoring uptime checks can monitor the monitoring VM itself from outside the VM. Recommended checks include Prometheus `/-/ready` on port `9090`, Grafana `/api/health` on port `3000`, and Alertmanager `/-/ready` on port `9093`, exposed only through approved firewall rules or an internal load balancer as appropriate. Google Cloud Monitoring can also cover GCE VM uptime, disk, GCS bucket-level signals, and synthetic checks that are outside Prometheus' own failure domain.

## False Positive Reduction

Alerts use `warning`, `critical`, and occasional `info` severities. Warnings indicate conditions that need investigation before they become outages. Critical alerts indicate likely user-impacting database availability, backup freshness, or HA failures.

Most alerts use a `for:` duration so short scrape glitches do not page immediately. Examples include 5 minutes for exporter scrape failures, 10 minutes for high connection usage, and 10 minutes for stale GCS backup state.

Alertmanager groups alerts by `alertname`, `cluster`, `site`, and `node`. The `site` label should be added to file service discovery targets when a deployment has on-prem and GCP sites, for example `site: onprem-tpe` or `site: gcp-asia-east1`. Grouping by site makes network partitions and site failures easier to read.

Inhibition rules are prepared for a future site-level alert named `KubereatsSiteUnreachable`. When that critical alert is firing for a `cluster` and `site`, lower-severity warning and info alerts from the same site can be inhibited to avoid alert storms. The site-level alert itself should come from blackbox probing, VPN tunnel checks, or Google Cloud Monitoring integration in a later phase.

Use Alertmanager silences for planned maintenance such as PostgreSQL failover drills, VM patching, backup tooling upgrades, or VPN maintenance. Prefer time-bounded silences scoped by `cluster`, `site`, `node`, or exact alert names.

Default thresholds are conservative. They are intended to avoid noisy alerts in a student cloud-native project while still catching important database risks: sustained exporter failure, PostgreSQL down, connection pressure above 80 percent, replication lag above 64 MiB, disk usage above 85 percent, and backup age above 26 hours.

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

## Kubernetes Monitoring Later

Do not deploy the primary database Prometheus/Grafana stack inside Kubernetes in this phase. Database monitoring should remain available even when the Kubernetes application cluster is unavailable.

A later Kubernetes monitoring add-on may use:

- `kube-prometheus-stack`
- `ServiceMonitor` for in-cluster application and Kubernetes exporters
- separate `additionalScrapeConfigs` if Kubernetes Prometheus needs a limited view of external dependencies
- Grafana dashboard ConfigMaps for Kubernetes and application dashboards
- Kubernetes Secrets, External Secrets, or Workload Identity for credentials

That future in-cluster stack should complement `gcp-monitor-01`, not replace it for database monitoring. Do not store GCP service account keys in Git. Prefer Workload Identity on GKE when possible.

## Future Work

- backend `/metrics`
- application health checks
- Loki or ELK logs
- OpenTelemetry tracing
- Kubernetes `ServiceMonitor` integration
- Grafana MCP-assisted dashboard iteration
