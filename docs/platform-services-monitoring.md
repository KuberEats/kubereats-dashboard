# Platform Services Monitoring

This document covers Kubernetes platform services outside application workloads.

## Current Cluster State

Present:

- ArgoCD
- CoreDNS
- kube-prometheus-stack

Not currently present:

- ingress controller
- MetalLB
- cert-manager
- external-dns
- StorageClass, PV, PVC

Dashboards include panels for these absent components so the same dashboard becomes useful when they are installed. Alert rules are written to avoid firing solely because an optional component is absent.

## CoreDNS

CoreDNS is monitored by the kube-prometheus-stack CoreDNS ServiceMonitor. Key signals:

- `up{job="coredns"}`
- `coredns_dns_responses_total`
- DNS error response ratio

## Ingress

No ingress controller is currently installed. If ingress-nginx is added later, expose controller metrics and add or verify a ServiceMonitor for the controller service. The platform dashboard expects standard ingress-nginx metrics such as:

```promql
nginx_ingress_controller_requests
nginx_ingress_controller_request_duration_seconds_bucket
```

## MetalLB

MetalLB is not currently installed. If added later, monitor controller and speaker availability, address pool usage, and BGP sessions if BGP mode is used.

## cert-manager

cert-manager is not currently installed. If added later, monitor controller availability and certificate expiration with:

```promql
certmanager_certificate_expiration_timestamp_seconds
```

## Storage

No StorageClass, PV, or PVC currently exists. PVC panels and alerts use kubelet volume stats and kube-state-metrics and will become active after persistent volumes are added.

## Dashboard

`Kubereats Platform Services` shows CoreDNS up/error rate, ingress status and latency when installed, MetalLB component status when installed, cert-manager certificate expiration when installed, and PVC/PV status when storage exists.
