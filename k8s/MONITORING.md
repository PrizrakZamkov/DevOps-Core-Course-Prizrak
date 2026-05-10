# Monitoring - Lab 16

## Overview

Lab 16 adds Kubernetes monitoring with kube-prometheus-stack and init containers for pod startup tasks.

The application already exposes Prometheus metrics at:

```text
/metrics
```

The Helm chart now can create a `ServiceMonitor` so Prometheus Operator can scrape the app.

## Stack Components

| Component | Role |
|-----------|------|
| Prometheus Operator | Manages Prometheus, Alertmanager, ServiceMonitor, and PrometheusRule resources |
| Prometheus | Stores and queries time-series metrics |
| Alertmanager | Receives alerts from Prometheus and routes notifications |
| Grafana | Visualizes metrics with dashboards |
| kube-state-metrics | Exposes Kubernetes object state metrics |
| node-exporter | Exposes node CPU, memory, disk, and network metrics |

## Install Kube-Prometheus Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

Verify:

```bash
kubectl get po,svc -n monitoring
```

Expected components:

```text
monitoring-grafana
monitoring-kube-prometheus-alertmanager
monitoring-kube-prometheus-operator
monitoring-kube-prometheus-prometheus
monitoring-kube-state-metrics
monitoring-prometheus-node-exporter
```

## Access UIs

Grafana:

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Login:

```text
admin / prom-operator
```

Prometheus:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

Alertmanager:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
```

## Dashboard Questions

Use these Grafana dashboards:

- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Pod
- Node Exporter / Nodes
- Kubernetes / Kubelet

Answers to collect during live run:

| Question | Where to check | Query or panel |
|----------|----------------|----------------|
| CPU/memory usage of StatefulSet | Namespace/Pod dashboard | filter namespace and pod prefix |
| Most/least CPU pods | Namespace Pods dashboard | CPU usage table |
| Node memory and CPU cores | Node Exporter / Nodes | memory and CPU panels |
| Pods/containers managed by kubelet | Kubernetes / Kubelet | running pods/containers panel |
| Network traffic in default namespace | Namespace dashboard | receive/transmit panels |
| Active alerts | Alertmanager UI | `http://localhost:9093` |

## Init Containers

Values file:

```text
k8s/system-info-api/values-monitoring.yaml
```

Download init container:

```yaml
initContainers:
  download:
    enabled: true
    image: busybox:1.36
    url: https://example.com
    fileName: index.html
    mountPath: /init-data
```

Wait-for-service init container:

```yaml
initContainers:
  waitForService:
    enabled: true
    image: busybox:1.36
    serviceName: kubernetes.default.svc.cluster.local
    intervalSeconds: 2
```

Verify init containers:

```bash
kubectl get pods -n monitoring-app -w
kubectl logs <pod-name> -n monitoring-app -c init-download
kubectl exec <pod-name> -n monitoring-app -- ls -la /init-data
kubectl exec <pod-name> -n monitoring-app -- cat /init-data/index.html
```

Expected:

```text
Init:0/2 -> Init:1/2 -> Running
index.html exists in /init-data
main container can read the file
```

## ServiceMonitor Bonus

Template:

```text
k8s/system-info-api/templates/servicemonitor.yaml
```

Values:

```yaml
serviceMonitor:
  enabled: true
  releaseLabel: release
  releaseName: monitoring
  path: /metrics
  interval: 15s
  scrapeTimeout: 10s
```

Deploy app:

```bash
helm upgrade --install system-info-monitoring k8s/system-info-api \
  -n monitoring-app --create-namespace \
  -f k8s/system-info-api/values-monitoring.yaml
```

Verify ServiceMonitor:

```bash
kubectl get servicemonitor -n monitoring-app
kubectl describe servicemonitor system-info-monitoring-system-info-api -n monitoring-app
```

Check Prometheus targets:

```text
http://localhost:9090/targets
```

PromQL examples:

```promql
up{job=~".*system-info.*"}
http_requests_total
http_request_duration_seconds_count
devops_info_endpoint_calls_total
```

## GitOps Integration

ArgoCD Application:

```text
k8s/argocd/application-monitoring.yaml
```

Deploy:

```bash
kubectl apply -f k8s/argocd/application-monitoring.yaml
```

## Docker Compose Monitoring

The repository also contains a local Docker Compose monitoring stack:

```text
monitoring/docker-compose.yml
monitoring/prometheus/prometheus.yml
```

It runs:

- Prometheus
- Grafana
- Loki
- Promtail
- system-info-api

The Prometheus config scrapes:

```yaml
- job_name: 'system-info-api'
  static_configs:
    - targets: ['system-info-api:6000']
  metrics_path: '/metrics'
```

## Commands Reference

```bash
kubectl get po,svc -n monitoring
kubectl get servicemonitor -A
kubectl get pods -n monitoring-app
kubectl logs <pod> -n monitoring-app -c init-download
kubectl exec <pod> -n monitoring-app -- cat /init-data/index.html
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
```

## Summary

Monitoring stack gives cluster metrics, dashboards, alerts, and app scraping. Init containers let the pod complete setup work before the main app starts.
