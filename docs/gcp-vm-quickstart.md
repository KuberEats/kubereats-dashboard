# GCP VM Quickstart

Use the monitoring VM at `10.250.0.4`. The stack binds to localhost, so browser access should go through SSH tunnels.

## Install Prerequisites On The VM

```bash
ssh 10.250.0.4
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git make
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
exit
```

Start a fresh SSH session after adding the user to the `docker` group.

## Clone Or Update The Repo

From the jump host:

```bash
ssh 10.250.0.4
git clone https://github.com/KuberEats/kubereats-dashboard.git || true
cd kubereats-dashboard
git pull
cp .env.example .env
vim .env
make validate
make up
make ps
```

If `.env` already exists, do not overwrite it. Review and update only the target values that changed.

## Runtime `.env` Values

The checked-in `.env.example` uses placeholders. For the current lab DB inventory, use these runtime target values on `10.250.0.4` if they are still accurate in `/home/edtsai/kubereats-IaC`:

```env
PG_NODE_1_NAME=pg1
PG_NODE_1_EXPORTER_TARGET=192.168.16.221:9187
PG_NODE_2_NAME=pg2
PG_NODE_2_EXPORTER_TARGET=192.168.16.222:9187
PG_NODE_3_NAME=pg3
PG_NODE_3_EXPORTER_TARGET=10.250.0.3:9187

PATRONI_NODE_1_TARGET=192.168.16.221:8008
PATRONI_NODE_2_TARGET=192.168.16.222:8008
PATRONI_NODE_3_TARGET=10.250.0.3:8008

DB_NODE_1_EXPORTER_TARGET=192.168.16.221:9100
DB_NODE_2_EXPORTER_TARGET=192.168.16.222:9100
DB_NODE_3_EXPORTER_TARGET=10.250.0.3:9100
```

Do not put database passwords or service account key JSON in Git.

## SSH Tunnel

From a local machine with access to the jump host:

```bash
ssh -J <jump-host-user>@<jump-host-public-ip> <monitor-user>@10.250.0.4 \
  -L 3000:127.0.0.1:3000 \
  -L 9090:127.0.0.1:9090 \
  -L 9093:127.0.0.1:9093
```

Then open:

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

## Verify

On `10.250.0.4`:

```bash
docker compose -f deploy/gcp-vm/docker-compose.yml ps
curl -fsS http://127.0.0.1:9090/-/healthy
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:9093/-/healthy
curl -s http://127.0.0.1:9090/api/v1/targets | head
```

If `jq` is installed:

```bash
curl -s http://127.0.0.1:9090/api/v1/targets \
  | jq -r '.data.activeTargets[] | [.labels.job, .labels.node, .health, .scrapeUrl] | @tsv'
```

DB targets can remain `down` until `postgres_exporter`, Patroni metrics, node exporter, and network firewall rules are in place on the DB nodes.

## DB Exporter Access

Current lab DB nodes:

```text
pg1 192.168.16.221
pg2 192.168.16.222
pg3 10.250.0.3
```

Access DB nodes from the jump host as `kubereats`:

```bash
ssh kubereats@192.168.16.221
ssh kubereats@192.168.16.222
ssh kubereats@10.250.0.3
```

Exporter ports:

- node_exporter: `9100`
- postgres_exporter: `9187`
- Patroni: `8008`

`node_exporter` and `postgres_exporter` are installed on `pg1`, `pg2`, and `pg3`. Restrict TCP/9100 and TCP/9187 to the monitoring VM source IP `10.250.0.4` and any explicitly required Kubernetes internal scrape ranges; do not allow exporter ports from `0.0.0.0/0`. `postgres_exporter` uses a low-privilege PostgreSQL monitoring user and a host-local systemd environment file; do not store its DSN or password in Git.

If central Prometheus cannot directly scrape `pg3`, it also federates selected `pg3` metrics from the Kubernetes-local Prometheus through private NodePort `30990` on `192.168.17.11`. This is an internal fallback path only; keep the NodePort private to the lab networks.
