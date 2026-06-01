# Kubernetes Monitoring

Kubereats Kubernetes metrics are collected inside the cluster by `kube-prometheus-stack` in the `monitoring` namespace. Central Grafana on `10.250.0.4` reads that Prometheus over the private Kubernetes node network.

```text
K8s nodes and pods
  -> kubelet, cAdvisor, kube-state-metrics, node-exporter
  -> kube-prometheus-stack Prometheus in monitoring
  -> private NodePort 192.168.17.11:30990
  -> central Grafana on 10.250.0.4
```

## Private Access

Central Grafana uses the `Kubernetes Prometheus` datasource:

```env
K8S_PROMETHEUS_URL=http://192.168.17.11:30990
```

The NodePort service is `monitoring/kube-prometheus-stack-prometheus-federation`. It must remain private. Firewall policy should allow only `10.250.0.4/32` to reach TCP `30990` on Kubernetes node IPs.

Do not expose Prometheus or node-exporter publicly.

## Why node-exporter is a DaemonSet

node-exporter runs once per Kubernetes node so Prometheus can collect host CPU, memory, filesystem, network, and load metrics from every node. It is scraped inside the cluster through a ClusterIP service, not through public node ports.

## Debug

```bash
kubectl get pods -n monitoring -o wide
kubectl get svc -n monitoring
kubectl get servicemonitor,prometheusrule -n monitoring
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Then inspect targets:

```bash
curl -s http://127.0.0.1:9090/api/v1/targets | jq .
```

Expected healthy target groups:

- `node-exporter`
- `kube-state-metrics`
- `kubelet`
- `coredns`
- ArgoCD metrics targets

## Dashboards

- `Kubereats K8s Cluster Overview`: cluster readiness, pod phases, deployments, CPU, memory, restarts, namespace usage.
- `Kubereats K8s Node Overview`: node CPU, memory, filesystem, network, load, node-exporter and kubelet target status.
- `Kubereats K8s Workload Health`: unavailable replicas, CrashLoopBackOff, restarts, pending and failed pods, OOMKilled containers, HPA state.

## Known Limitations

- Prometheus uses ephemeral storage because no stable StorageClass is currently present.
- Some default control-plane scrape targets are down because kube-controller-manager, scheduler, etcd, and kube-proxy are not exposing metrics on the expected node interfaces. kubelet, cAdvisor, CoreDNS, kube-state-metrics, and node-exporter are healthy.
