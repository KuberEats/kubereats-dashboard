# Backend Autoscaling Monitoring

Kubereats backend autoscaling uses KEDA ScaledObjects to create HPAs in the
`kubereats-dev` namespace. Central Grafana reads the live HPA, deployment, pod,
and service metrics from the Kubernetes Prometheus datasource:

```env
K8S_PROMETHEUS_URL=http://192.168.17.11:30990
```

The central Prometheus on `10.250.0.4` also federates the same autoscaling
signals from the Kubernetes Prometheus NodePort so they are available locally
for Prometheus queries and alerting.

## Dashboard

Dashboard JSON:

```text
grafana/dashboards/kubereats-backend-autoscaling.json
```

Dashboard title:

```text
Kubereats Backend Autoscaling
```

The dashboard shows:

- HPA current and desired replicas
- HPAs currently at max replicas
- HPA AbleToScale status
- backend deployment available and total replicas
- backend pod CPU and memory
- backend pod restarts
- Merchant Service business counters
- Order Consumer throughput and failures

## Prometheus Federation

Central Prometheus job:

```text
k8s-prometheus-federate-backend-autoscaling
```

Useful local Prometheus queries on `10.250.0.4`:

```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="kubereats-dev"}
kube_horizontalpodautoscaler_status_desired_replicas{namespace="kubereats-dev"}
kube_horizontalpodautoscaler_spec_max_replicas{namespace="kubereats-dev"}
kube_deployment_status_replicas_available{namespace="kubereats-dev"}
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="kubereats-dev", container!="", container!="POD"}[5m]))
sum(rate(merchant_apply_total{namespace="kubereats-dev"}[5m]))
sum(rate(order_consumer_reservation_processed_total{namespace="kubereats-dev"}[5m]))
```

## Verify

On the monitoring VM:

```bash
curl -fsS http://127.0.0.1:9090/-/healthy
curl -gs http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=kube_horizontalpodautoscaler_status_current_replicas{namespace="kubereats-dev"}' \
  | jq .
curl -fsS http://10.250.0.4:3000/api/health
```
