# LAB11 - Kubernetes Secrets and HashiCorp Vault

**Student:** PrizrakZamkov on github (Stanislav Delyukov)  
**Date:** 2026-04-09  
**Topic:** Kubernetes Secrets, Helm secret management, HashiCorp Vault  
**Status:** Repository implementation completed, Helm validation passed, cluster verification requires local execution

---

## Overview

In this lab, the Helm chart from Lab 10 was extended to support secret management in two ways:

1. Native Kubernetes Secrets
2. HashiCorp Vault Agent Injector

The implementation was added to the existing chart in `k8s/system-info-api/`. Documentation required by the lab is stored in `k8s/SECRETS.md`.

---

## Repository Changes

### Helm Chart

The following files were added or updated:

```text
k8s/
\-- system-info-api/
    +-- values.yaml
    \-- templates/
        +-- _helpers.tpl
        +-- deployment.yaml
        +-- secrets.yaml
        \-- serviceaccount.yaml
```

### What Was Implemented

- Kubernetes Secret template via Helm
- configurable secret values in `values.yaml`
- injection of secrets into the container with `envFrom.secretRef`
- dedicated ServiceAccount for Vault auth binding
- Vault Agent Injector annotations in the pod template
- bonus support for Vault Agent templates
- named helper template for reusable environment variables
- documentation in `k8s/SECRETS.md`

---

## Task 1 - Kubernetes Secrets Fundamentals

### Command Used

```powershell
kubectl create secret generic app-credentials `
  --from-literal=username=demo-user `
  --from-literal=password=demo-password
```

### Secret Representation

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
data:
  username: ZGVtby11c2Vy
  password: ZGVtby1wYXNzd29yZA==
```

### Decode Demonstration

```powershell
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZGVtby11c2Vy'))
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZGVtby1wYXNzd29yZA=='))
```

Result:

```text
demo-user
demo-password
```

### Security Conclusion

- Kubernetes Secrets are base64-encoded, not truly encrypted by default
- anyone with sufficient API access can read and decode them
- production clusters should enable etcd encryption at rest and RBAC restrictions

---

## Task 2 - Helm-Managed Secrets

### Secret Values in Chart

```yaml
secret:
  enabled: true
  create: true
  data:
    username: "change-me"
    password: "change-me"
```

### Secret Template

```yaml
apiVersion: v1
kind: Secret
stringData:
  username: "change-me"
  password: "change-me"
```

### Deployment Integration

```yaml
envFrom:
  - secretRef:
      name: {{ include "system-info-api.secretName" . }}
```

### Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

### Verification Commands

```powershell
helm upgrade --install my-app .\k8s\system-info-api `
  --set secret.data.username=app-user `
  --set secret.data.password=app-password

kubectl get pods
kubectl exec -it deploy/my-app-system-info-api -- printenv | Select-String "username|password"
kubectl describe pod <pod-name>
```

Expected result:

- secret variables are available inside the container
- `kubectl describe pod` does not reveal the secret values themselves

---

## Task 3 - Vault Integration

### Vault Installation

```powershell
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault `
  --namespace vault `
  --create-namespace `
  --set "server.dev.enabled=true" `
  --set "injector.enabled=true"
```

### Vault Secret and Auth Setup

```sh
vault secrets enable -path=secret kv-v2

vault kv put secret/system-info-api/config \
  username="vault-user" \
  password="vault-password"

vault auth enable kubernetes

vault policy write system-info-api - <<EOF
path "secret/data/system-info-api/config" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/system-info-api \
  bound_service_account_names="my-app-system-info-api" \
  bound_service_account_namespaces="default" \
  policies="system-info-api" \
  ttl="1h"
```

### Helm Values for Vault

```powershell
helm upgrade --install my-app .\k8s\system-info-api `
  --set secret.enabled=false `
  --set vault.enabled=true `
  --set vault.role=system-info-api `
  --set vault.secretPath=secret/data/system-info-api/config
```

### Bonus Template Support

The chart can render a custom file via Vault Agent template:

```yaml
vault:
  template: |
    {{- with secret "secret/data/system-info-api/config" -}}
    APP_USERNAME={{ .Data.data.username }}
    APP_PASSWORD={{ .Data.data.password }}
    {{- end }}
```

This produces `/vault/secrets/config` in the pod.

---

## What You Need To Do Manually

`helm` is installed and the chart passed `helm lint`, but this workstation still has no active Kubernetes context. These steps must still be executed against your cluster:

1. Connect `kubectl` to your cluster or start Minikube
2. Run the documented `helm upgrade --install` commands
3. Run the verification commands from `k8s/SECRETS.md`
4. Capture screenshots from the verification steps

---

## Screenshot Checklist

Save screenshots into `app_python/docs/lab11screens/`.

Take these screenshots:

1. `kubectl get secret app-credentials -o yaml`
2. base64 decode command output
3. Helm chart file tree with `secrets.yaml`
4. successful `helm upgrade --install`
5. `kubectl exec ... printenv`
6. `kubectl get pods -n vault`
7. Vault configuration commands or policy creation
8. `cat /vault/secrets/config` inside the pod

---

## Final Result

Lab 11 is prepared in the repository:

- chart implementation is added
- lab documentation is written
- exact commands for verification are provided
- screenshot plan is prepared

Main deliverables:

- `k8s/SECRETS.md`
- `app_python/docs/LAB11.md`
- updated Helm chart in `k8s/system-info-api/`
