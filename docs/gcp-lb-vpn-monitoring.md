# GCP Load Balancer, HA VPN, and Cloud Router Monitoring

This runbook extends the central Kubereats monitoring stack on `10.250.0.4` with Google Cloud Monitoring visibility for GCP-managed resources.

GCP-managed Load Balancer, HA VPN, Cloud Router, and GCS resources should be observed through Cloud Monitoring. Prometheus should not scrape these APIs directly. Cloud Logging is used for event investigation and troubleshooting, not as the primary metrics source.

## Project and Access

- Project ID: `project-7e4d63c9-6a51-487b-866`
- Monitoring VM: `instance-20260527-145143`
- Monitoring VM zone: `asia-east1-c`
- Monitoring VM service account: `63367291685-compute@developer.gserviceaccount.com`
- Central Grafana datasource: `Google Cloud Monitoring`
- Datasource authentication: GCE metadata service

Required IAM for the monitoring VM service account:

```bash
gcloud projects add-iam-policy-binding project-7e4d63c9-6a51-487b-866 \
  --member='serviceAccount:63367291685-compute@developer.gserviceaccount.com' \
  --role='roles/monitoring.viewer'
```

Optional IAM for log querying through Grafana or automation:

```bash
gcloud projects add-iam-policy-binding project-7e4d63c9-6a51-487b-866 \
  --member='serviceAccount:63367291685-compute@developer.gserviceaccount.com' \
  --role='roles/logging.viewer'
```

Optional IAM for future automated resource inventory:

```bash
gcloud projects add-iam-policy-binding project-7e4d63c9-6a51-487b-866 \
  --member='serviceAccount:63367291685-compute@developer.gserviceaccount.com' \
  --role='roles/compute.viewer'
```

Grafana should use direct GCE metadata authentication from the monitoring VM. After the monitoring VM scope update, the metadata service exposes `cloud-platform` scope and the Grafana datasource health check can query the Cloud Monitoring API successfully.

## Discovered Resources

Global forwarding rules:

| Name | IP | Target |
| --- | --- | --- |
| `kubereats-frontend` | `8.232.93.117` | `kubereats-global-lb-target-proxy` |
| `kubereats-frontend-forwarding-rule` | `8.232.93.117` | `kubereats-frontend-target-proxy` |

Target proxies and URL maps:

| Type | Name | URL map |
| --- | --- | --- |
| HTTPS target proxy | `kubereats-global-lb-target-proxy` | `kubereats-global-lb` |
| HTTP target proxy | `kubereats-frontend-target-proxy` | `kubereats-frontend-redirect` |

Global backend services:

| Backend service | NEG | Health |
| --- | --- | --- |
| `committee-backend` | `committee-service-site-a` | all endpoints healthy |
| `finance-backend` | `finance-service-site-a` | all endpoints healthy |
| `kubereats-site-a` | `test-bk101` | all endpoints healthy |
| `merchant-backend` | `merchant-service-site-a` | all endpoints healthy |
| `order-scheduler` | `order-scheduler-service-site-a` | all endpoints healthy |
| `recommendation-backend` | `recommendation-service-site-a` | all endpoints healthy |
| `tagging-backend` | `tagging-service-sita-a` | all endpoints healthy |
| `verification-backend` | `verification-service-site-a` | all endpoints healthy |

Network endpoint groups:

- `committee-service-site-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`
- `finance-service-site-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`
- `merchant-service-site-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`
- `order-scheduler-service-site-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`
- `recommendation-service-site-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`
- `tagging-service-sita-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`
- `test-bk101`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `2`
- `verification-service-site-a`, `asia-east1-a`, `NON_GCP_PRIVATE_IP_PORT`, size `4`

VPN and router:

| Resource | Name | Region | Details |
| --- | --- | --- | --- |
| HA VPN gateway | `site-a-ha-vpn` | `asia-east1` | interfaces `35.242.36.233`, `35.220.39.129` |
| VPN tunnel | `pa850-tunnel` | `asia-east1` | peer `140.113.215.254` |
| VPN tunnel | `pa-tunnel-2` | `asia-east1` | peer `140.113.215.254` |
| Cloud Router | `site-a-router` | `asia-east1` | network `hybrid-vpc` |

Cloud Router status:

- `site-a-bgp-session`: `UP`, `Established`, peer `169.254.179.178`, learned routes `1`
- `site-a-bgp-session-2`: `UP`, `Established`, peer `169.254.1.50`, learned routes `1`
- learned route: `192.168.16.0/20`
- advertised routes include `10.250.0.0/24`, `10.250.100.0/24`, `35.191.0.0/16`, and `130.211.0.0/22`

## Metric Descriptors

Use these discovered descriptors for dashboards and alert policies. Do not hard-code descriptors that are absent from the project.

Load Balancing descriptors discovered: `54`

```text
loadbalancing.googleapis.com/application_lb/backend_latencies
loadbalancing.googleapis.com/application_lb/backend_request_bytes_count
loadbalancing.googleapis.com/application_lb/backend_request_count
loadbalancing.googleapis.com/application_lb/backend_response_bytes_count
loadbalancing.googleapis.com/application_lb/request_bytes_count
loadbalancing.googleapis.com/application_lb/request_count
loadbalancing.googleapis.com/application_lb/response_bytes_count
loadbalancing.googleapis.com/application_lb/total_latencies
loadbalancing.googleapis.com/https/backend_latencies
loadbalancing.googleapis.com/https/backend_request_bytes_count
loadbalancing.googleapis.com/https/backend_request_count
loadbalancing.googleapis.com/https/backend_response_bytes_count
loadbalancing.googleapis.com/https/external/regional/backend_latencies
loadbalancing.googleapis.com/https/external/regional/backend_request_bytes_count
loadbalancing.googleapis.com/https/external/regional/backend_request_count
loadbalancing.googleapis.com/https/external/regional/backend_response_bytes_count
loadbalancing.googleapis.com/https/external/regional/request_bytes_count
loadbalancing.googleapis.com/https/external/regional/request_count
loadbalancing.googleapis.com/https/external/regional/response_bytes_count
loadbalancing.googleapis.com/https/external/regional/total_latencies
loadbalancing.googleapis.com/https/frontend_tcp_rtt
loadbalancing.googleapis.com/https/internal/backend_latencies
loadbalancing.googleapis.com/https/internal/backend_request_bytes_count
loadbalancing.googleapis.com/https/internal/backend_request_count
loadbalancing.googleapis.com/https/internal/backend_response_bytes_count
loadbalancing.googleapis.com/https/internal/request_bytes_count
loadbalancing.googleapis.com/https/internal/request_count
loadbalancing.googleapis.com/https/internal/response_bytes_count
loadbalancing.googleapis.com/https/internal/total_latencies
loadbalancing.googleapis.com/https/request_bytes_count
loadbalancing.googleapis.com/https/request_count
loadbalancing.googleapis.com/https/response_bytes_count
loadbalancing.googleapis.com/https/total_latencies
loadbalancing.googleapis.com/l3/external/egress_bytes_count
loadbalancing.googleapis.com/l3/external/egress_packets_count
loadbalancing.googleapis.com/l3/external/ingress_bytes_count
loadbalancing.googleapis.com/l3/external/ingress_packets_count
loadbalancing.googleapis.com/l3/external/rtt_latencies
loadbalancing.googleapis.com/l3/internal/egress_bytes_count
loadbalancing.googleapis.com/l3/internal/egress_packets_count
loadbalancing.googleapis.com/l3/internal/ingress_bytes_count
loadbalancing.googleapis.com/l3/internal/ingress_packets_count
loadbalancing.googleapis.com/l3/internal/rtt_latencies
loadbalancing.googleapis.com/l4_proxy/egress_bytes_count
loadbalancing.googleapis.com/l4_proxy/ingress_bytes_count
loadbalancing.googleapis.com/l4_proxy/tcp/closed_connections_count
loadbalancing.googleapis.com/l4_proxy/tcp/new_connections_count
loadbalancing.googleapis.com/subnet/proxy_only/addresses
loadbalancing.googleapis.com/tcp_ssl_proxy/closed_connections
loadbalancing.googleapis.com/tcp_ssl_proxy/egress_bytes_count
loadbalancing.googleapis.com/tcp_ssl_proxy/frontend_tcp_rtt
loadbalancing.googleapis.com/tcp_ssl_proxy/ingress_bytes_count
loadbalancing.googleapis.com/tcp_ssl_proxy/new_connections
loadbalancing.googleapis.com/tcp_ssl_proxy/open_connections
```

VPN descriptors discovered: `9`

```text
vpn.googleapis.com/gateway/connections
vpn.googleapis.com/network/dropped_received_packets_count
vpn.googleapis.com/network/dropped_sent_packets_count
vpn.googleapis.com/network/received_bytes_count
vpn.googleapis.com/network/received_packets_count
vpn.googleapis.com/network/sent_bytes_count
vpn.googleapis.com/network/sent_packets_count
vpn.googleapis.com/tunnel_established
vpn.googleapis.com/vpn_tunnel/gateway_ip_version
```

Cloud Router descriptors discovered: `31`

```text
router.googleapis.com/best_received_routes_count
router.googleapis.com/bfd/control/receive_intervals
router.googleapis.com/bfd/control/received_packets_count
router.googleapis.com/bfd/control/rejected_packets_count
router.googleapis.com/bfd/control/transmit_intervals
router.googleapis.com/bfd/control/transmitted_packets_count
router.googleapis.com/bfd/session_flap_events_count
router.googleapis.com/bfd/session_up
router.googleapis.com/bgp/received_routes_count
router.googleapis.com/bgp/sent_routes_count
router.googleapis.com/bgp/session_up
router.googleapis.com/bgp_sessions_down_count
router.googleapis.com/bgp_sessions_up_count
router.googleapis.com/dynamic_routes/learned_routes/any_dropped_unique_destinations
router.googleapis.com/dynamic_routes/learned_routes/dropped_unique_destinations
router.googleapis.com/dynamic_routes/learned_routes/unique_destinations_limit
router.googleapis.com/dynamic_routes/learned_routes/used_unique_destinations
router.googleapis.com/nat/allocated_ports
router.googleapis.com/nat/closed_connections_count
router.googleapis.com/nat/dropped_received_packets_count
router.googleapis.com/nat/dropped_sent_packets_count
router.googleapis.com/nat/nat_allocation_failed
router.googleapis.com/nat/new_connections_count
router.googleapis.com/nat/open_connections
router.googleapis.com/nat/port_usage
router.googleapis.com/nat/received_bytes_count
router.googleapis.com/nat/received_packets_count
router.googleapis.com/nat/sent_bytes_count
router.googleapis.com/nat/sent_packets_count
router.googleapis.com/router_up
router.googleapis.com/sent_routes_count
```

The dashboard skeletons use only descriptors from the lists above. If Grafana needs a different query shape for the installed Stackdriver datasource version, keep the same metric descriptors and adjust only the panel query JSON through the Grafana UI.

## Dashboard Files

- `grafana/dashboards/kubereats-gcp-load-balancer-overview.json`
- `grafana/dashboards/kubereats-gcp-vpn-router-overview.json`

Suggested LB panels:

- HTTPS request rate grouped by response code class
- backend latency p95
- total latency p95
- request and response throughput

Suggested HA VPN and Cloud Router panels:

- VPN tunnel established
- BGP session up
- sent and received tunnel throughput
- dropped sent and received packets
- BGP routes sent and received

## Cloud Logging Queries

Useful resource types discovered:

- `http_load_balancer`
- `vpn_gateway`
- `vpn_tunnel`
- `gce_router`
- `gce_forwarding_rule`
- `gce_network_endpoint_group`

Recent HTTP load balancer logs were available under:

```text
projects/project-7e4d63c9-6a51-487b-866/logs/requests
```

Recent VPN gateway logs were available under:

```text
projects/project-7e4d63c9-6a51-487b-866/logs/cloud.googleapis.com%2Fipsec_events
```

Recent Cloud Router logs were available under:

```text
projects/project-7e4d63c9-6a51-487b-866/logs/compute.googleapis.com%2Frouter_events
```

Load balancer failures:

```text
resource.type="http_load_balancer"
severity>=WARNING
```

Load balancer backend responses:

```text
resource.type="http_load_balancer"
jsonPayload.statusDetails="response_sent_by_backend"
```

VPN gateway events:

```text
resource.type="vpn_gateway"
logName="projects/project-7e4d63c9-6a51-487b-866/logs/cloud.googleapis.com%2Fipsec_events"
```

Cloud Router route and BGP events:

```text
resource.type="gce_router"
logName="projects/project-7e4d63c9-6a51-487b-866/logs/compute.googleapis.com%2Frouter_events"
```

There were no recent `vpn_tunnel` rows returned during discovery. Prefer `vpn_gateway` and `gce_router` for current tunnel and BGP event investigation.

## Cloud Monitoring Alert Policy Recommendations

Create these in Cloud Monitoring so GCP-managed LB/VPN alerts still fire if the self-hosted monitoring VM is down.

Recommended policies:

- LB 5xx rate high: `loadbalancing.googleapis.com/https/request_count`, align as rate, filter `metric.label.response_code_class = 500`, alert when the 5xx rate or 5xx percentage exceeds the production threshold for 5 minutes.
- Backend unhealthy: use LB/backend health status if exposed in Cloud Monitoring for the backend service, or alert from Cloud Load Balancing health check resources when an endpoint becomes unhealthy.
- VPN tunnel down: `vpn.googleapis.com/tunnel_established`, alert when any tunnel is `0` for 5 minutes.
- BGP session down: `router.googleapis.com/bgp/session_up`, alert when any session is `0` for 5 minutes.
- Unexpected VPN traffic drop: `vpn.googleapis.com/network/sent_bytes_count` and `vpn.googleapis.com/network/received_bytes_count`, align as rate, alert when near zero during known traffic windows.
- Cloud Router route change: `router.googleapis.com/bgp/received_routes_count` or `router.googleapis.com/best_received_routes_count`, alert when learned route count changes unexpectedly.

Do not create these policies automatically until notification channels and thresholds are agreed.
