# ArgoCD Implementation Guide

This document describes the GitOps continuous deployment setup using ArgoCD for the system-info-api Helm chart.

---

## Installation

### Prerequisites

- Kubernetes cluster (1.20+)
- Helm 3.0+
- kubectl configured to access your cluster
- Sufficient cluster permissions to create namespaces and install operators

### Step 1: Add ArgoCD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Step 2: Create ArgoCD Namespace

```bash
kubectl create namespace argocd
```

### Step 3: Install ArgoCD

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values - <<EOF
server:
  insecure: true
  service:
    type: LoadBalancer

controller:
  replicas: 1

repoServer:
  replicas: 1

applicationSet:
  replicas: 1
EOF
```

### Step 4: Verify Installation

```bash
kubectl get pods -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

Expected output: All pods in Running state

```
NAME                                    READY   STATUS    RESTARTS   AGE
argocd-application-controller-0         1/1     Running   0          60s
argocd-applicationset-controller-6...   1/1     Running   0          60s
argocd-dex-server-59d8c7d5cf-xxxxx      1/1     Running   0          60s
argocd-redis-xxxxx                      1/1     Running   0          60s
argocd-repo-server-xxxxx                1/1     Running   0          60s
argocd-server-xxxxx                     1/1     Running   0          60s
```

---

## UI Access

### Port Forwarding

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: `https://localhost:8080` or `http://localhost:8080` (with insecure flag)

### Get Initial Admin Password

```bash
# Bash/Linux/macOS
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# PowerShell
$base64String = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64String))
```

### Login Credentials

- **Username:** admin
- **Password:** (retrieved from secret above)

---

## CLI Setup

### Install ArgoCD CLI

**Linux:**
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd
```

**macOS (Homebrew):**
```bash
brew install argocd
```

**Windows (PowerShell):**
```powershell
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe -OutFile argocd.exe
Move-Item argocd.exe C:\Windows\System32\  # or add to PATH
```

### CLI Login

```bash
argocd login localhost:8080 --insecure
# Username: admin
# Password: (use password from secret)
```

Verify connection:
```bash
argocd cluster list
argocd project list
```

---

## Application Deployment

### File Structure

```
k8s/
├── argocd/
│   ├── namespace.yaml
│   ├── application-dev.yaml
│   ├── application-prod.yaml
│   └── applicationset.yaml
└── system-info-api/
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-prod.yaml
    └── ...
```

### Create Namespaces

```bash
kubectl apply -f k8s/argocd/namespace.yaml
```

Verify:
```bash
kubectl get namespaces | grep -E "argocd|dev|prod"
```

### Deploy Applications

#### Option 1: Individual Applications

```bash
kubectl apply -f k8s/argocd/application-dev.yaml
kubectl apply -f k8s/argocd/application-prod.yaml
```

Verify:
```bash
kubectl get applications -n argocd
argocd app list
```

#### Option 2: ApplicationSet (Bonus)

```bash
kubectl apply -f k8s/argocd/applicationset.yaml
```

This will automatically generate both dev and prod applications.

---

## Configuration Details

### Development Environment

**File:** `k8s/argocd/application-dev.yaml`

**Key Features:**
- Values file: `values-dev.yaml`
- Namespace: `dev`
- Sync policy: **Automatic**
  - Auto-prune: Delete resources removed from Git
  - Self-heal: Revert manual cluster changes
- Replica count: 1
- Resource limits: Minimal (100m CPU, 128Mi memory)

**Why Auto-Sync for Dev?**
- Fast feedback loop for testing
- Automatic deployment of commits
- Easier development iteration
- Safe to revert in dev environment

### Production Environment

**File:** `k8s/argocd/application-prod.yaml`

**Key Features:**
- Values file: `values-prod.yaml`
- Namespace: `prod`
- Sync policy: **Manual**
  - No auto-sync
  - No auto-prune
- Replica count: 5
- Resource limits: Higher (500m CPU, 512Mi memory)
- Image tag: Pinned to specific version (e.g., `2.0.0`)

**Why Manual Sync for Prod?**
- Change review before deployment
- Controlled release timing
- Compliance and audit requirements
- Rollback planning and execution
- Prevention of accidental deletions

### Sync Policy Comparison

| Feature | Dev | Prod |
|---------|-----|------|
| Auto-sync | ✅ Yes | ❌ No |
| Self-heal | ✅ Yes | ❌ No |
| Prune | ✅ Yes | ❌ No |
| Manual trigger | ✅ Allowed | ✅ Required |
| Deployment time | Immediate | ~5-10 min (review) |

---

## Multi-Environment Values

### Development (values-dev.yaml)

```yaml
replicaCount: 1
environment: development
logLevel: DEBUG
resources:
  limits:
    cpu: 100m
    memory: 128Mi
persistence:
  size: 50Mi
```

### Production (values-prod.yaml)

```yaml
replicaCount: 5
environment: production
logLevel: INFO
service:
  type: ClusterIP
resources:
  limits:
    cpu: 500m
    memory: 512Mi
persistence:
  size: 200Mi
```

---

## Self-Healing & Sync Testing

### Manual Scale Test (Development)

**Test:** Force deployment to different replica count

```bash
# Scale manually (create drift)
kubectl scale deployment system-info-api -n dev --replicas=5

# Check deployment
kubectl get deployment -n dev

# Check ArgoCD status (should show OutOfSync)
argocd app get python-app-dev
argocd app diff python-app-dev
```

**Expected Behavior:**
1. ArgoCD detects drift within 3 minutes (default polling)
2. Status shows "OutOfSync"
3. With `selfHeal: true`, ArgoCD reverts to 1 replica
4. Deployment returns to desired state

**Verification:**
```bash
# Watch the pods return to 1 replica
kubectl get pods -n dev -w

# Confirm sync status
argocd app get python-app-dev
# Should show: Synced and Healthy
```

### Pod Deletion Test

**Test:** Delete a pod and observe behavior

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n dev -o jsonpath='{.items[0].metadata.name}')

# Delete the pod
kubectl delete pod $POD_NAME -n dev

# Watch Kubernetes recreate it immediately
kubectl get pods -n dev -w
```

**Key Insight:**
- **Kubernetes Self-Healing:** ReplicaSet controller recreates pods immediately
  - Pod deletion triggers ReplicaSet to create replacement
  - Happens within seconds
  
- **ArgoCD Self-Healing:** Reverts configuration drift
  - Manual changes to resources get reverted
  - Happens at next sync interval or immediately (if enabled)

**Result:** Pod is recreated by Kubernetes within 5 seconds

### Configuration Drift Test

**Test:** Manually edit a resource and observe reversion

```bash
# Add a label manually
kubectl label pod $POD_NAME -n dev drift-test=true

# Check difference
argocd app diff python-app-dev

# Manual change should be shown as difference
# With selfHeal: true, will be reverted at next sync
```

**Expected Behavior:**
1. Change applied successfully
2. ArgoCD detects difference in 3 minutes
3. Status shows "OutOfSync"
4. Self-heal reverts the change
5. Status returns to "Synced"

---

## Sync Behavior Reference

### Sync Triggers

| Trigger | Interval |
|---------|----------|
| Git polling | 3 minutes (default) |
| Webhook | Immediate |
| Manual trigger | Immediate |
| Sync waves | Sequential |

### Sync Status

| Status | Meaning |
|--------|---------|
| **Synced** | Cluster matches Git exactly |
| **OutOfSync** | Git has changes not applied |
| **Unknown** | Unable to determine state |
| **Healthy** | All resources are healthy |
| **Degraded** | Some resources unhealthy |
| **Progressing** | Sync/update in progress |

### Retry Configuration

All applications include retry logic:
```yaml
retry:
  limit: 5              # Max 5 attempts
  backoff:
    duration: 5s        # Initial 5s
    factor: 2           # Double each time
    maxDuration: 3m     # Cap at 3 minutes
```

This gives exponential backoff: 5s → 10s → 20s → 40s → 80s

---

## ApplicationSet Pattern

The ApplicationSet feature (bonus) provides template-based application generation:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: python-app-set
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            namespace: dev
            valuesFile: values-dev.yaml
            autoSync: "true"
          - env: prod
            namespace: prod
            valuesFile: values-prod.yaml
            autoSync: "false"

  template:
    metadata:
      name: 'python-app-{{env}}'
    spec:
      # ...
      destination:
        namespace: '{{namespace}}'
      # ...
```

### Benefits

- **DRY Principle:** Single template, multiple applications
- **Scalability:** Easy to add new environments
- **Consistency:** All apps follow same pattern
- **Maintainability:** Update template once, applies everywhere

### Generator Types

| Generator | Use Case |
|-----------|----------|
| **List** | Explicit list of parameters |
| **Cluster** | Multi-cluster deployments |
| **Git** | Auto-discover from Git structure |
| **Matrix** | Combine multiple generators |
| **Merge** | Merge outputs from other generators |

---

## Troubleshooting

### Application Stuck in "Unknown" Status

```bash
argocd app get python-app-dev --refresh

# Check if argocd-repo-server is running
kubectl get pods -n argocd | grep repo-server
```

### Helm Chart Not Found

Verify:
1. Repository URL is correct
2. Path is correct relative to repo root
3. Chart exists at that path

```bash
# From repo root, verify chart exists
ls -la k8s/system-info-api/Chart.yaml
```

### Secrets Cannot Be Decrypted

ArgoCD needs access to encrypted secrets. Ensure:
1. Kubernetes secrets are in the target namespace
2. RBAC allows reading secrets
3. ArgoCD service account has proper permissions

```bash
kubectl get secret -n dev
argocd account rbac list
```

### Sync Fails with "CREATE" Errors

Check:
1. CreateNamespace sync option is enabled
2. Current user/service account has permission to create namespaces
3. Namespace doesn't already exist with conflicting resources

---

## Best Practices

1. **Git as Source of Truth**
   - All changes via Git commits
   - No manual `kubectl` commands
   - Every change is auditable

2. **Environment Separation**
   - Use different namespaces per environment
   - Use different values files per environment
   - Different sync policies for risk levels

3. **Secret Management**
   - Don't store secrets in Git
   - Use Kubernetes Secrets or external Secret manager
   - ArgoCD Sealed Secrets or Bitnami Sealed Secrets

4. **Monitoring**
   - Monitor ArgoCD application status
   - Set up notifications for sync failures
   - Regular audit of drift detection

5. **RBAC**
   - Limit ArgoCD server access
   - Separate read/write permissions
   - Service account per application

---

## References

- [Official ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Application Specification](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [GitOps Principles](https://opengitops.dev/)
