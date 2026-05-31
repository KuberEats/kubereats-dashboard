# Kubereats Database Monitoring

Kubereats depends on PostgreSQL for order, menu, merchant, and user data. Phase 1 monitoring focuses on database observability because DB degradation can become user-visible before backend application checks are mature. The goal is actionable operator signals, not a dump of every exported metric.

## Architecture

The monitoring stack runs on the GCP monitoring VM at `10.250.0.4`, outside the Kubernetes application cluster:

- Prometheus scrapes metrics and evaluates alert rules.
- Grafana reads Prometheus through a provisioned datasource and loads dashboard JSON from Git.
- Alertmanager receives Prometheus alerts. Notification receivers are intentionally deployment-specific placeholders.
- `postgres_exporter` should run on each PostgreSQL node and expose database metrics on `:9187`.
- Patroni metrics are scraped from each DB node on `:8008` when `/metrics` is available.
- node_exporter should run on each DB node and expose host metrics on `:9100`.
- `gcs-backup-exporter` runs beside Prometheus and checks the configured GCS backup bucket and prefix.

The current lab DB nodes from the IaC repo are `pg1` at `192.168.16.221`, `pg2` at `192.168.16.222`, and `pg3` at `10.250.0.3`. Keep these values in the monitoring VM `.env`; do not commit environment-specific runtime files.

DB node SSH access is through the `kubereats` user:

```bash
ssh kubereats@192.168.16.221
ssh kubereats@192.168.16.222
ssh kubereats@10.250.0.3
```

Exporter ports:

- node_exporter: `9100`
- postgres_exporter: `9187`
- Patroni metrics/API: `8008`

Restrict DB exporter access to the monitoring VM source IP `10.250.0.4`. Do not open exporter ports to `0.0.0.0/0`.

## Why Outside Kubernetes

This stack intentionally runs outside Kubernetes for Phase 1. If Kubernetes is unhealthy, operators still need a view of PostgreSQL health, Patroni leadership, DB node disk pressure, and backup freshness. Keeping the monitoring plane on `10.250.0.4` avoids putting the database observability path in the same failure domain as the application workloads.

## Why Grafana Is Not HA Yet

Grafana is not HA in this phase because the priority is establishing repeatable monitoring-as-code and useful DB dashboards. A single Grafana instance with provisioned dashboards is acceptable for the first production-like setup. The known risk is that the monitoring VM is a single point of failure; Git-backed configuration makes restoration straightforward. HA Grafana, remote metric storage, and standby monitoring VMs are future work.

## Why DB Monitoring Comes Before Backend Health Checks

The backend services do not yet expose application `/metrics` or a full health model. Database signals are already operationally meaningful: exporter reachability, `pg_up`, connection pressure, replication lag, deadlocks, Patroni leader state, disk usage, and backup freshness all indicate risk before customers see failed orders or login issues.

## Component Flow

Prometheus scrapes static targets for `postgres-exporter`, `patroni`, `db-node-exporter`, `gcs-backup-exporter`, and itself. Grafana uses the provisioned `Prometheus` datasource at `http://prometheus:9090`. Dashboards are loaded from `/var/lib/grafana/dashboards`. Alert rules live under `prometheus/rules/` and are sent to Alertmanager at `http://alertmanager:9093`.

The GCS backup exporter uses Google Application Default Credentials. The monitoring VM service account needs:

- `storage.objects.list`
- `storage.objects.get` if backup object metadata access requires it

The exporter exposes:

- `kubereats_gcs_backup_last_check_success`
- `kubereats_gcs_backup_latest_object_timestamp_seconds`
- `kubereats_gcs_backup_latest_object_age_seconds`
- `kubereats_gcs_backup_objects_total`
- `kubereats_gcs_backup_max_age_seconds`

## False Positive Reduction

Alerts use sustained `for:` windows so one missed scrape does not become a critical incident. Exporter scrape failures wait 5 minutes. Connection pressure, disk pressure, replication lag, stale backups, and backup exporter failures wait 10 minutes. Critical alerts are reserved for likely service impact: PostgreSQL down, no Patroni leader, and stale backups beyond the configured backup SLO.

Labels are deliberately low-cardinality: `env`, `cluster`, `component`, and `node`. Avoid labels based on SQL text, client address, pod name, request ID, or object path.

## Warning Vs Critical

Use `warning` when an operator should investigate before users are likely impacted, such as exporter down, high connection usage, replication lag, deadlocks, disk usage above 85%, or backup exporter check failures.

Use `critical` when service impact is likely or data durability is at risk: PostgreSQL reports down, Patroni has no leader, or the latest backup is older than the configured max age.

## Runbook Notes

### Alert KubereatsPostgresExporterDown

Prometheus cannot scrape `postgres_exporter`. Check whether the exporter package or service is installed, whether it listens on `:9187`, whether the monitoring VM can reach the DB node, and whether host firewalls allow the path.

### Alert KubereatsPostgresDown

`postgres_exporter` is reachable but `pg_up=0`. Check PostgreSQL process status, local exporter credentials, PostgreSQL port access, and Patroni state on that node.

### Alert KubereatsPostgresConnectionsHigh

Connection usage is above 80% of `max_connections`. Check backend connection pools, stuck sessions, idle-in-transaction sessions, and recent traffic changes.

### Alert KubereatsPostgresReplicationLagHigh

Replication lag is above 64 MiB for 10 minutes. Check replica health, WAL receiver status, network latency, disk pressure, and whether Patroni has recently failed over.

### Alert KubereatsPostgresDeadlocksDetected

Deadlocks increased. Review recent write paths, transaction ordering, lock waits, and application retries.

### Alert KubereatsPatroniNoLeader

No Patroni target reports a leader. Check Patroni API reachability, etcd/DCS health, node clocks, and quorum. Do not force promotion without understanding quorum and data loss risk.

### Alert KubereatsDbDiskUsageHigh

A DB node filesystem is above 85% usage. Check data volume, WAL growth, logs, pgBackRest retention, and filesystem mount points.

As of the initial DB node exporter rollout, `node_exporter` is installed as a systemd service on `pg1`, `pg2`, and `pg3`. Host-level firewall rules should allow local loopback checks and `10.250.0.4/32` to TCP/9100, then drop other TCP/9100 sources. If Prometheus still reports a node exporter target down, test from the monitoring VM first:

```bash
curl -fsS http://192.168.16.221:9100/metrics | head
curl -fsS http://192.168.16.222:9100/metrics | head
curl -fsS http://10.250.0.3:9100/metrics | head
```

If `pg3` times out from `10.250.0.4` while local checks on `pg3` succeed, check the GCP VPC firewall or route between `10.250.0.4` and `10.250.0.3`. The firewall rule should be restricted to source `10.250.0.4/32` and TCP/9100 for node_exporter. Patroni on `pg3` uses TCP/8008 and may need a similarly restricted rule if central Prometheus should scrape it.

### Alert KubereatsGcsBackupTooOld

The latest observed GCS backup object is older than `GCS_BACKUP_MAX_AGE_HOURS`. Check pgBackRest timers, recent backup job logs, GCS bucket and prefix values, IAM permissions, and whether the expected primary or backup host is running jobs.

### Alert KubereatsGcsBackupExporterFailed

The exporter is running but could not complete its latest GCS check. Check Application Default Credentials, VM service account IAM, bucket name, prefix, and outbound network access.

## If The On-Prem Site Is Down

The monitoring VM in GCP should remain reachable. Expect `pg1` and `pg2` scrape targets to fail if they are on-prem. Use Grafana to confirm whether `pg3` is still up and whether Patroni/etcd quorum can safely elect a leader. The current two-on-prem, one-GCP DB topology may not auto-promote with a full on-prem outage because the remaining GCP node alone lacks quorum.

## If Kubernetes Is Down

Keep using the monitoring VM. This stack is intentionally outside Kubernetes and should still show DB, backup, and node-exporter state. Treat application errors separately from database health until backend metrics are implemented.

## If The Monitoring VM Is Down

Prometheus, Grafana, and Alertmanager from this stack are unavailable until `10.250.0.4` is restored. Recreate the VM, install Docker/Git, clone this repo, restore `.env` from operational records, and run `make up`. Add external uptime checks in a future phase to detect monitoring-plane failure.

## PostgreSQL Exporter User

Use a low-privilege monitoring user and keep the password in a secret manager or host-local config, never in Git:

```sql
CREATE USER postgres_exporter WITH PASSWORD 'CHANGE_ME';
GRANT pg_monitor TO postgres_exporter;
```

For the current IaC role, `prometheus-postgres-exporter` is installed on DB nodes only when `monitoring_enabled` is true. Confirm the role is using a safe credential before enabling it broadly.

## Dashboards

The provisioned dashboards are intentionally small:

- `Kubereats PostgreSQL Overview`: PostgreSQL up/down, exporter scrape status, active/max connections, transaction rate, locks/deadlocks, and database size.
- `Kubereats PostgreSQL HA`: Patroni leader state, replication lag, primary/replica signals, WAL activity, and node availability.
- `Kubereats GCS Backup`: latest backup age, freshness status, object count, latest object timestamp, exporter success, and the 26-hour backup SLO.

## Future Work

- backend service `/metrics`
- backend service `/healthz`
- kube-prometheus-stack for Kubernetes-native monitoring
- Grafana MCP-assisted dashboard iteration
- Google Cloud Monitoring uptime checks
- Loki or ELK logs
- OpenTelemetry tracing
- HA monitoring VM or remote metric storage
