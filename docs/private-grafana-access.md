# Private Grafana Access

Grafana is normally bound to loopback on the central monitoring VM:

```env
GRAFANA_BIND_ADDRESS=127.0.0.1
```

When a private GCP HTTPS load balancer backend needs to reach Grafana on the monitoring VM, set this only on the monitoring VM runtime `.env`:

```env
GRAFANA_BIND_ADDRESS=10.250.0.4
```

Keep Prometheus, Alertmanager, and exporters bound to loopback. Do not expose Grafana to `0.0.0.0/0`.

The monitoring VM should use a narrow firewall rule for TCP `3000`, scoped to known internal and load-balancer source ranges only. For the current Kubereats GCP environment:

```bash
gcloud compute instances add-tags kubereats-monitor \
  --zone asia-east1-b \
  --tags grafana-lb-backend

gcloud compute firewall-rules create allow-grafana-private-lb \
  --network hybrid-vpc \
  --direction INGRESS \
  --priority 1000 \
  --target-tags grafana-lb-backend \
  --source-ranges 10.250.0.0/24,10.250.100.0/24,35.191.0.0/16,130.211.0.0/22 \
  --rules tcp:3000
```

`35.191.0.0/16` and `130.211.0.0/22` are the Google Cloud load-balancer health-check/proxy ranges used by external Application Load Balancers. `10.250.100.0/24` is the current proxy-only subnet. `10.250.0.0/24` allows private access from the monitor VPC subnet.

After changing `.env`, recreate Grafana:

```bash
docker compose --env-file .env -f deploy/gcp-vm/docker-compose.yml up -d grafana
```

Verify:

```bash
curl -s http://10.250.0.4:3000/api/health
ss -ltnp | grep ':3000'
```
