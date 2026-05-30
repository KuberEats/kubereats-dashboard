# Prometheus File Service Discovery

These files intentionally contain no active external targets by default, so the repository does not commit private infrastructure addresses.

Example `patroni.yml`:

```yaml
- targets:
    - db-node-1.example.internal:8008
  labels:
    component: patroni
    node: pg-a
```

Example `db-node-exporter.yml`:

```yaml
- targets:
    - db-node-1.example.internal:9100
  labels:
    component: db-vm
    node: pg-a
```
