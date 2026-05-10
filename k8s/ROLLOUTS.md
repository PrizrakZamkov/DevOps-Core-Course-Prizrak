# Argo Rollouts - Lab 14

## Setup

Install controller:

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

Install dashboard:

```bash
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
```

Open:

```text
http://localhost:3100
```

Verify:

```bash
kubectl get pods -n argo-rollouts
kubectl argo rollouts version
```

## Rollout vs Deployment

`Deployment` supports regular rolling updates. `Rollout` is compatible with the same pod template, but adds progressive delivery strategies.

Main differences:

| Deployment | Rollout |
|------------|---------|
| RollingUpdate or Recreate | Canary and blue-green |
| Kubernetes controls rollout | Argo Rollouts controller controls rollout |
| No manual promotion step | Manual or automatic promotion |
| Basic rollback | Abort, retry, promote, undo |
| No analysis steps | AnalysisTemplate can stop bad releases |

## Canary Strategy

File:

```text
k8s/system-info-api/values-rollout-canary.yaml
```

Strategy:

```yaml
rollout:
  enabled: true
  strategy: canary
  canary:
    steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause:
          duration: 30s
      - setWeight: 60
      - pause:
          duration: 30s
      - setWeight: 80
      - pause:
          duration: 30s
      - setWeight: 100
```

Deploy:

```bash
helm upgrade --install system-info-canary k8s/system-info-api \
  -n rollout-canary --create-namespace \
  -f k8s/system-info-api/values-rollout-canary.yaml
```

Watch:

```bash
kubectl argo rollouts get rollout system-info-canary-system-info-api -n rollout-canary -w
```

Promote after first manual pause:

```bash
kubectl argo rollouts promote system-info-canary-system-info-api -n rollout-canary
```

Abort test:

```bash
kubectl argo rollouts abort system-info-canary-system-info-api -n rollout-canary
```

Expected behavior:

- new version receives 20% traffic first
- rollout waits for manual promotion
- then moves to 40%, 60%, 80%, and 100%
- abort shifts traffic back to stable revision

## Blue-Green Strategy

File:

```text
k8s/system-info-api/values-rollout-bluegreen.yaml
```

Strategy:

```yaml
rollout:
  enabled: true
  strategy: blueGreen
  blueGreen:
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 30
    previewService:
      type: ClusterIP
```

Deploy:

```bash
helm upgrade --install system-info-bluegreen k8s/system-info-api \
  -n rollout-bluegreen --create-namespace \
  -f k8s/system-info-api/values-rollout-bluegreen.yaml
```

Access active service:

```bash
kubectl port-forward svc/system-info-bluegreen-system-info-api -n rollout-bluegreen 8080:80
```

Access preview service:

```bash
kubectl port-forward svc/system-info-bluegreen-system-info-api-preview -n rollout-bluegreen 8081:80
```

Promote preview to active:

```bash
kubectl argo rollouts promote system-info-bluegreen-system-info-api -n rollout-bluegreen
```

Expected behavior:

- active service keeps serving stable version
- preview service exposes new version
- promotion switches active traffic to green instantly
- rollback switches service selector back quickly

## Bonus: Automated Analysis

File:

```text
k8s/system-info-api/templates/analysis-template.yaml
```

The canary values enable a web health check:

```yaml
rollout:
  analysis:
    enabled: true
    interval: 10s
    count: 3
    failureLimit: 1
    healthPath: /health
    expectedStatus: healthy
```

Rendered AnalysisTemplate checks:

```text
http://<service>.<namespace>.svc.cluster.local/health
```

If the health check does not return `{"status":"healthy"}`, the analysis fails and the canary can be stopped before full rollout.

## GitOps Applications

Optional ArgoCD Application manifests:

```text
k8s/argocd/application-rollout-canary.yaml
k8s/argocd/application-rollout-bluegreen.yaml
```

Apply:

```bash
kubectl apply -f k8s/argocd/application-rollout-canary.yaml
kubectl apply -f k8s/argocd/application-rollout-bluegreen.yaml
```

## Strategy Comparison

| Case | Canary | Blue-green |
|------|--------|------------|
| Release speed | Gradual | Instant switch |
| Risk control | Best for real traffic testing | Best for fast rollback |
| Resource usage | Lower | Higher during rollout |
| User exposure | Small percent first | All users switch after promotion |
| Best use | APIs, risky releases, metrics-based rollout | UI/API releases that need preview testing |

My recommendation:

- use canary when release risk is unknown and metrics can decide success
- use blue-green when preview testing is required before users see the new version

## Useful Commands

```bash
kubectl argo rollouts list rollouts -A
kubectl argo rollouts get rollout <name> -n <namespace>
kubectl argo rollouts promote <name> -n <namespace>
kubectl argo rollouts abort <name> -n <namespace>
kubectl argo rollouts retry rollout <name> -n <namespace>
kubectl argo rollouts undo <name> -n <namespace>
```
