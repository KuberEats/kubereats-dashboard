# Future Kubernetes Deployment

This repository does not ship Kubernetes manifests yet. A later production deployment should likely use:

- `kube-prometheus-stack` for Prometheus, Alertmanager, Grafana, and CRDs.
- `ServiceMonitor` objects for exporters running inside the cluster.
- `additionalScrapeConfigs` for external PostgreSQL VMs, Patroni APIs, and node exporters.
- Grafana dashboard ConfigMaps generated from `grafana/dashboards`.
- Kubernetes Secrets, External Secrets, or Workload Identity for credentials.

Do not store GCP service account keys, PostgreSQL passwords, or private network addresses in Git.
