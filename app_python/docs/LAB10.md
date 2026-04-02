# Lab 10 — Helm Package Manager

**Student:** PrizrakZamkov on github (Stanilav Delyukov)  
**Date:** 2026-03-27  
**Points:**

---

## Overview

Converted Kubernetes manifests from Lab 09 into a production-ready Helm chart with multi-environment support.

**Chart:** system-info-api v0.1.0  
**App Version:** 2.0.0  
**Helm Version:** 3.x

---

## Chart Structure

```
system-info-api/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── values-dev.yaml         # Development overrides
├── values-prod.yaml        # Production overrides
└── templates/
    ├── deployment.yaml     # Deployment template
    ├── service.yaml        # Service template
    ├── _helpers.tpl        # Template helpers
    └── NOTES.txt           # Post-install notes
```

---

## Installation

### Prerequisites

- Kubernetes cluster (minikube or production)
- Helm 3.x installed
- kubectl configured

### Quick Start

```bash
# Install with default values
helm install my-app system-info-api

# Install with dev values
helm install my-app-dev system-info-api -f system-info-api/values-dev.yaml

# Install with prod values
helm install my-app-prod system-info-api -f system-info-api/values-prod.yaml
```

### Verification

```bash
# Check release
helm list

# Check pods
kubectl get pods

# Access application
minikube service my-app-system-info-api --url
# or
kubectl port-forward service/my-app-system-info-api 8080:80
curl http://localhost:8080/health
```

---

## Configuration

### Default Values (values.yaml)

| Parameter                   | Description        | Default                         |
| --------------------------- | ------------------ | ------------------------------- |
| `replicaCount`              | Number of replicas | `3`                             |
| `image.repository`          | Image repository   | `prizrakzamkov/system-info-api` |
| `image.tag`                 | Image tag          | `latest`                        |
| `image.pullPolicy`          | Image pull policy  | `Always`                        |
| `service.type`              | Service type       | `NodePort`                      |
| `service.port`              | Service port       | `80`                            |
| `service.targetPort`        | Container port     | `6000`                          |
| `service.nodePort`          | NodePort number    | `30080`                         |
| `resources.limits.cpu`      | CPU limit          | `200m`                          |
| `resources.limits.memory`   | Memory limit       | `256Mi`                         |
| `resources.requests.cpu`    | CPU request        | `100m`                          |
| `resources.requests.memory` | Memory request     | `128Mi`                         |

### Development Environment (values-dev.yaml)

- 1 replica for cost efficiency
- Latest image tag
- Relaxed resource limits
- NodePort service for easy access

### Production Environment (values-prod.yaml)

- 5 replicas for high availability
- Specific image tag (2.0.0)
- Proper resource allocation
- ClusterIP service (use with Ingress)

---

## Usage Examples

### Install

```bash
# Default install
helm install my-app system-info-api

# With custom values
helm install my-app system-info-api \
  --set replicaCount=3 \
  --set image.tag=2.0.0
```

### Upgrade

```bash
# Upgrade with new values file
helm upgrade my-app system-info-api -f values-prod.yaml

# Upgrade single value
helm upgrade my-app system-info-api --set replicaCount=5
```

### Rollback

```bash
# View history
helm history my-app

# Rollback to previous revision
helm rollback my-app

# Rollback to specific revision
helm rollback my-app 1
```

### Uninstall

```bash
helm uninstall my-app
```

---

## Health Checks

Chart includes both liveness and readiness probes:

**Liveness Probe:**

- Path: `/health`
- Port: `6000`
- Initial Delay: `10s`
- Period: `10s`

**Readiness Probe:**

- Path: `/health`
- Port: `6000`
- Initial Delay: `5s`
- Period: `5s`

Both probes are fully configurable via values.

---

## Template Helpers

Chart uses standard Helm helpers from `_helpers.tpl`:

- `system-info-api.name` - Chart name
- `system-info-api.fullname` - Full resource name
- `system-info-api.chart` - Chart label
- `system-info-api.labels` - Common labels
- `system-info-api.selectorLabels` - Selector labels

---

## Testing

### Lint Chart

```bash
helm lint system-info-api
```

### Template Rendering

```bash
# Render templates locally
helm template my-app system-info-api

# Render with specific values
helm template my-app system-info-api -f values-prod.yaml
```

### Dry Run

```bash
helm install --dry-run --debug my-app system-info-api
```

---

## Deployment Evidence

### Chart Validation

```bash
$ helm lint system-info-api
==> Linting system-info-api
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

all data on screenshots

## Best Practices Implemented

✅ **Chart Metadata:** Complete Chart.yaml with version, description, maintainers  
✅ **Values Structure:** Nested, organized values.yaml  
✅ **Template Helpers:** Reusable `_helpers.tpl` functions  
✅ **Health Checks:** Liveness and readiness probes configured  
✅ **Resources:** CPU and memory limits set  
✅ **Labels:** Kubernetes recommended labels  
✅ **Documentation:** Inline comments and NOTES.txt  
✅ **Testing:** Lint, template, dry-run before deploy  
✅ **Multi-Env:** Separate values files for dev/prod

---

---

## Summary

Successfully converted static Kubernetes manifests into a flexible, reusable Helm chart with:

- ✅ Proper templating
- ✅ Multi-environment support
- ✅ Production-ready configuration
- ✅ Complete documentation
- ✅ Tested deployment workflow

**Chart Location:** `k8s/system-info-api/`  
**Status:** ✅ Production Ready

---

**Lab Completed:** March 27, 2026
