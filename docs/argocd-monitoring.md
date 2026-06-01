# ArgoCD Monitoring

ArgoCD is monitored by ServiceMonitors in the `monitoring` namespace. The ServiceMonitors select the real ArgoCD services in the `argocd` namespace.

## Monitored Components

- `argocd-metrics`: application-controller metrics
- `argocd-server-metrics`: API/server metrics
- `argocd-repo-server`: repo-server metrics on the `metrics` port
- `argocd-applicationset-controller`: ApplicationSet controller metrics
- `argocd-notifications-controller-metrics`: notifications controller metrics

`argocd-redis` does not expose a Prometheus metrics port in the current install, so Redis availability is monitored through Kubernetes deployment availability. `argocd-dex-server` exposes a service metrics port, but the endpoint refused connections during validation, so it is intentionally not scraped.

## Why Monitor ArgoCD

ArgoCD is the deployment control plane. Monitoring sync status, health status, Git fetch failures, and controller latency catches broken GitOps reconciliation before it becomes an application incident.

## Alerts

The Kubernetes Prometheus rule `kubereats-platform-alerts` includes:

- `KubereatsArgoCDAppDegraded`
- `KubereatsArgoCDAppOutOfSync`
- `KubereatsArgoCDAppSyncFailed`
- `KubereatsArgoCDServerDown`
- `KubereatsArgoCDRepoServerDown`
- `KubereatsArgoCDApplicationControllerDown`
- `KubereatsArgoCDRedisDown`
- `KubereatsArgoCDAppReconcileSlow`
- `KubereatsArgoCDGitFetchFailures`

OutOfSync is warning-only with a 15 minute hold time to avoid normal sync transition noise.

## Debug

```bash
kubectl get svc -n argocd
kubectl get servicemonitor -n monitoring | grep argocd
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Useful Prometheus queries:

```promql
argocd_app_info
up{namespace="argocd"}
rate(argocd_app_sync_total[5m])
histogram_quantile(0.95, sum(rate(argocd_app_reconcile_bucket[10m])) by (le))
```

## Dashboard

`Kubereats ArgoCD Overview` shows app sync state, app health state, component up status, sync operation rate, failed sync count, repo-server request rate, reconcile latency, and a table of degraded or out-of-sync applications.
