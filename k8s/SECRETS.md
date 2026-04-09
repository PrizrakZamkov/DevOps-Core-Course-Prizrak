# Lab 11 - Kubernetes Secrets and HashiCorp Vault

## What Was Added

This repository now contains the Lab 11 implementation in the Helm chart at `k8s/system-info-api/`:

- `templates/secrets.yaml` for Kubernetes Secret creation
- `templates/serviceaccount.yaml` for a dedicated ServiceAccount
- Vault Agent Injector annotations in `templates/deployment.yaml`
- named Helm helpers in `templates/_helpers.tpl`
- secret and Vault configuration in `values.yaml`

The chart supports two secret delivery modes:

1. Native Kubernetes Secret injected as environment variables with `envFrom`
2. HashiCorp Vault Agent Injector that renders secrets into files under `/vault/secrets/`

---

## 1. Kubernetes Secrets Fundamentals

### Create Secret with kubectl

```powershell
kubectl create secret generic app-credentials `
  --from-literal=username=demo-user `
  --from-literal=password=demo-password
```

### View Secret in YAML

```powershell
kubectl get secret app-credentials -o yaml
```

Expected structure:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
data:
  username: ZGVtby11c2Vy
  password: ZGVtby1wYXNzd29yZA==
```

### Decode Base64 Values

```powershell
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZGVtby11c2Vy'))
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZGVtby1wYXNzd29yZA=='))
```

Decoded values:

```text
demo-user
demo-password
```

### Base64 vs Encryption

- Base64 is only encoding. It makes bytes printable, but does not protect the content.
- Anyone who can read the Secret object can decode the values immediately.
- Kubernetes Secrets are not meaningfully protected unless you also use RBAC and enable encryption at rest for etcd.

### Are Secrets Encrypted at Rest by Default?

No. In a default Kubernetes setup, Secret values are only base64-encoded in the API object and stored in etcd without encryption at rest unless cluster administrators explicitly enable it.

### What Is etcd Encryption?

etcd encryption at rest is a Kubernetes control-plane feature that encrypts sensitive resources, including `Secret` objects, before storing them in etcd. You should enable it in any non-trivial cluster, especially in shared, staging, or production environments.

---

## 2. Helm Secret Integration

### Chart Changes

Secret configuration was added to `k8s/system-info-api/values.yaml`:

```yaml
secret:
  enabled: true
  create: true
  name: ""
  type: Opaque
  data:
    username: "change-me"
    password: "change-me"
```

Secret template:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "system-info-api.secretName" . }}
type: Opaque
stringData:
  username: "change-me"
  password: "change-me"
```

### How the Deployment Consumes Secrets

The Deployment now uses:

```yaml
envFrom:
  - secretRef:
      name: {{ include "system-info-api.secretName" . }}
```

This injects all keys from the Secret as environment variables inside the container.

### Deploy the Chart

Replace placeholder values during install or upgrade:

```powershell
helm upgrade --install my-app .\k8s\system-info-api `
  --set secret.data.username=app-user `
  --set secret.data.password=app-password
```

### Verify Secret Injection

```powershell
kubectl get pods
kubectl exec -it deploy/my-app-system-info-api -- printenv | Select-String "username|password|HOST|PORT"
kubectl describe pod <pod-name>
```

What to verify:

- `printenv` shows environment variables from the Secret
- `kubectl describe pod` shows the `secretRef` source, but not the secret values themselves

---

## 3. Resource Management

Resource requests and limits are already configured in `values.yaml`:

```yaml
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Requests vs Limits

- `requests` reserve the minimum CPU and memory the scheduler should guarantee
- `limits` cap the maximum CPU and memory a container may consume

### Choosing Values

- Start from real usage observed with `kubectl top`
- Keep requests close to normal steady-state usage
- Keep limits above typical peaks, but not so high that noisy workloads affect node stability

For this lab, the selected values are appropriate for a small Flask service.

---

## 4. Vault Integration

### Helm Chart Support Added

`values.yaml` now includes Vault configuration:

```yaml
vault:
  enabled: false
  role: "system-info-api"
  authPath: "auth/kubernetes"
  secretPath: "secret/data/system-info-api/config"
  fileName: "config"
```

When `vault.enabled=true`, the pod receives Vault Agent Injector annotations and a `VAULT_SECRET_FILE=/vault/secrets/config` environment variable.

### Install Vault

```powershell
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault `
  --namespace vault `
  --create-namespace `
  --set "server.dev.enabled=true" `
  --set "injector.enabled=true"
```

### Verify Vault Pods

```powershell
kubectl get pods -n vault
```

Expected result:

- `vault-0` is `Running`
- Vault injector pod is also `Running`

### Configure Vault

Open a shell inside the Vault pod:

```powershell
kubectl exec -it -n vault vault-0 -- sh
```

Inside the pod, run:

```sh
vault secrets enable -path=secret kv-v2

vault kv put secret/system-info-api/config \
  username="vault-user" \
  password="vault-password"

vault auth enable kubernetes

cat <<'EOF' > /tmp/system-info-api-policy.hcl
path "secret/data/system-info-api/config" {
  capabilities = ["read"]
}
EOF

vault policy write system-info-api /tmp/system-info-api-policy.hcl

vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

vault write auth/kubernetes/role/system-info-api \
  bound_service_account_names="my-app-system-info-api" \
  bound_service_account_namespaces="default" \
  policies="system-info-api" \
  ttl="1h"
```

### Enable Vault Injection in the Chart

```powershell
helm upgrade --install my-app .\k8s\system-info-api `
  --set secret.enabled=false `
  --set vault.enabled=true `
  --set vault.role=system-info-api `
  --set vault.secretPath=secret/data/system-info-api/config
```

### Verify Injection

```powershell
kubectl get pod
kubectl exec -it <pod-name> -- ls /vault/secrets
kubectl exec -it <pod-name> -- cat /vault/secrets/config
```

What to verify:

- `/vault/secrets/config` exists
- file content is rendered by Vault Agent
- pod has the injected sidecar/init workflow from Vault

### Sidecar Injection Pattern

Vault Agent Injector mutates the pod during admission:

- adds Vault agent containers
- authenticates the pod using its Kubernetes ServiceAccount token
- fetches secrets from Vault
- renders them into files inside the pod filesystem

This keeps secrets out of Git and out of static Kubernetes Secret manifests.

---

## 5. Bonus - Vault Agent Templates

The chart already includes support for:

- `vault.hashicorp.com/agent-inject-template-*`
- `vault.hashicorp.com/agent-inject-command-*`
- a named Helm helper for reusable environment variables

Default template in `values.yaml`:

```yaml
template: |
  {{- with secret "secret/data/system-info-api/config" -}}
  APP_USERNAME={{ .Data.data.username }}
  APP_PASSWORD={{ .Data.data.password }}
  {{- end }}
```

### How Rotation Works

- Vault Agent periodically renews or refreshes secrets depending on the backend and lease model
- when rendered content changes, the target file is updated in the pod
- `vault.hashicorp.com/agent-inject-command-*` can run a command after file refresh, for example to signal or restart the application process

---

## 6. Security Analysis

### Kubernetes Secrets vs Vault

| Aspect | Kubernetes Secret | HashiCorp Vault |
|---|---|---|
| Storage | Kubernetes API / etcd | External secret manager |
| Default protection | Base64 only | Strong access control and auditing |
| Rotation | Manual or custom automation | Native workflows and dynamic secrets |
| Auditability | Limited | Strong audit capabilities |
| Best fit | Small internal configs | Production-grade secret management |

### When to Use Each

- Use Kubernetes Secrets for simple labs, low-risk configs, and bootstrap values
- Use Vault for production, multi-team clusters, rotating credentials, and centralized secret governance

### Production Recommendations

- enable etcd encryption at rest
- restrict Secret access with RBAC
- avoid storing real credentials in Git or plain `values.yaml`
- prefer external secret managers such as Vault
- use dedicated ServiceAccounts instead of `default`

---

## 7. Screenshot Checklist

Add screenshots to `app_python/docs/lab11screens/` and reference them from `app_python/docs/LAB11.md`.

Recommended screenshots:

1. Secret creation or `kubectl get secret app-credentials -o yaml`
2. Base64 decode demonstration
3. Helm chart files showing `secrets.yaml`
4. Pod environment verification with `kubectl exec ... printenv`
5. `kubectl describe pod` proving values are not printed
6. `kubectl get pods -n vault`
7. Vault policy/role or Vault CLI commands
8. `/vault/secrets/config` inside the application pod

---

## 8. Validation and Limitation

The chart was validated locally with Helm:

```text
helm lint k8s/system-info-api
1 chart(s) linted, 0 chart(s) failed
```

I could not run the live cluster steps in this environment because `kubectl` currently has no configured context.

Because of that, commands that require a running Kubernetes cluster are documented as exact steps for you to execute locally.
