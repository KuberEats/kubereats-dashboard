# Future Kubernetes Monitoring

This phase intentionally does not deploy the primary Prometheus, Grafana, or Alertmanager stack inside Kubernetes.

Database monitoring should run outside the application cluster, preferably on the independent GCP VM `gcp-monitor-01`, so PostgreSQL and backup observability remain available when Kubernetes is unhealthy or unavailable.

A later Kubernetes monitoring add-on may use:

- `kube-prometheus-stack` for Kubernetes control plane, node, pod, and application metrics.
- `ServiceMonitor` objects for exporters running inside the cluster.
- `additionalScrapeConfigs` only when the in-cluster stack needs a limited view of external dependencies.
- Grafana dashboard ConfigMaps for Kubernetes and application dashboards.
- Kubernetes Secrets, External Secrets, or Workload Identity for credentials.

The Kubernetes stack should complement `gcp-monitor-01`, not replace it for database monitoring. Do not store GCP service account keys, PostgreSQL passwords, or private network addresses in Git.
