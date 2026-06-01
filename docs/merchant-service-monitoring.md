# Merchant Service Monitoring

Merchant Service exports Prometheus metrics on its existing HTTP port at `/metrics`.

The Kubernetes integration uses a `ServiceMonitor` that scrapes the in-cluster `merchant-service` Service in `kubereats-dev`. No public port is added, and node-exporter is not exposed.

## Metrics

Custom Merchant Service metrics discovered from `/metrics`:

```text
merchant_apply_total
merchant_menu_created_total
merchant_menu_deleted_total
merchant_orders_confirmed_total
merchant_request_duration_seconds
```

The endpoint also exposes standard Python and process metrics such as:

```text
python_gc_collections_total
process_cpu_seconds_total
process_resident_memory_bytes
process_virtual_memory_bytes
```

## Prometheus

Verify the target through the central monitor path:

```bash
curl -s http://192.168.17.11:30990/api/v1/targets | jq '.data.activeTargets[] | select(.labels.service=="merchant-service")'
```

Useful queries:

```promql
up{namespace="kubereats-dev", service="merchant-service"}
increase(merchant_apply_total[30m])
increase(merchant_menu_created_total[30m])
increase(merchant_menu_deleted_total[30m])
increase(merchant_orders_confirmed_total[30m])
histogram_quantile(0.95, sum(rate(merchant_request_duration_seconds_bucket[10m])) by (le))
```

## Grafana

Dashboard JSON:

```text
grafana/dashboards/kubereats-merchant-service-metrics.json
```

Dashboard title:

```text
Kubereats Merchant Service Metrics
```

The dashboard uses the `Kubernetes Prometheus` datasource.
