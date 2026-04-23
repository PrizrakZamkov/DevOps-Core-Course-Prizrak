# Lab 12 — ConfigMaps & Persistent Volumes

**Student:** PrizrakZamkov  
**Date:** 2026-03-27  
**Points:** all

---

## Overview

Extended application with persistent visits counter and externalized configuration using Kubernetes ConfigMaps and PersistentVolumeClaims.

**Key Features:**
- Visit counter with file-based persistence
- ConfigMaps for configuration management
- PersistentVolumeClaim for data survival
- Multi-environment support (dev/prod)

---

## Application Changes

### Visits Counter

**New Endpoints:**
- `/` - Returns app info + visits count (increments counter)
- `/visits` - Returns current visits count (read-only)

**Implementation:**
- Counter stored in `/data/visits` file
- Increments on each request to root endpoint
- Persists across pod restarts via PVC

**File:** `app_python/app.py`

```python
VISITS_FILE = Path('/data/visits')

def get_visits():
    """Read visits count from file"""
    try:
        if VISITS_FILE.exists():
            return int(VISITS_FILE.read_text().strip())
    except Exception as e:
        logger.error(f'Error reading visits: {e}')
    return 0

def increment_visits():
    """Increment and save visits count"""
    try:
        VISITS_FILE.parent.mkdir(parents=True, exist_ok=True)
        count = get_visits() + 1
        VISITS_FILE.write_text(str(count))
        return count
    except Exception as e:
        logger.error(f'Error writing visits: {e}')
        return get_visits()
```

---

## ConfigMaps Implementation

### Structure

**Two ConfigMaps created:**

1. **File-based ConfigMap** (`-config`)
   - Contains `config.json`
   - Mounted at `/config/config.json`
   - Read-only volume

2. **Environment Variables ConfigMap** (`-env`)
   - Contains key-value pairs
   - Injected as environment variables
   - Configurable per environment

### Configuration File

**File:** `k8s/system-info-api/files/config.json`

```json
{
  "app_name": "System Info API",
  "environment": "production",
  "features": {
    "metrics_enabled": true,
    "visits_enabled": true,
    "health_checks": true
  },
  "logging": {
    "level": "INFO",
    "format": "json"
  }
}
```

### ConfigMap Template

**File:** `templates/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "system-info-api.fullname" . }}-config
data:
  config.json: |-
{{ .Files.Get "files/config.json" | indent 4 }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "system-info-api.fullname" . }}-env
data:
  APP_ENV: {{ .Values.environment | quote }}
  LOG_LEVEL: {{ .Values.logLevel | quote }}
  FEATURES_METRICS: {{ .Values.features.metrics | quote }}
```

### Consumption in Deployment

**File mount:**
```yaml
volumes:
  - name: config-volume
    configMap:
      name: {{ include "system-info-api.fullname" . }}-config

volumeMounts:
  - name: config-volume
    mountPath: /config
    readOnly: true
```

**Environment variables:**
```yaml
envFrom:
  - configMapRef:
      name: {{ include "system-info-api.fullname" . }}-env
```

---

## Persistent Volume

### PersistentVolumeClaim

**File:** `templates/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "system-info-api.fullname" . }}-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
```

**Configuration in values.yaml:**
```yaml
persistence:
  enabled: true
  size: 100Mi
  storageClass: ""  # Use minikube default
```

### Volume Mount

```yaml
volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: {{ include "system-info-api.fullname" . }}-data

volumeMounts:
  - name: data-volume
    mountPath: /data
```

### Access Mode: ReadWriteOnce

- Volume can be mounted by a single node
- Multiple pods on same node can access
- Appropriate for single-replica or node-affinity deployments

**Storage Class:**
- minikube provides `standard` storage class
- Auto-provisions hostPath volumes
- Data stored on minikube VM

---

## Evidence

### Screenshot 1: Docker Push
**File:** in `app_python/docs/lab12screens`

Successfully pushed updated image with visits counter to Docker Hub.

### Screenshot 2: Resources Created
**File:** `app_python/docs/lab12screens`

```bash
kubectl get all,cm,pvc
```

Shows:
- 3 pods (replicaCount: 3)
- 1 service (NodePort)
- 1 deployment
- 1 replicaset
- 2 configmaps (config + env)
- 1 pvc (data, Bound status)

### Screenshot 3: ConfigMap Verification
**File:** `app_python/docs/lab12screens`

ConfigMap mounted as file:
```bash
kubectl exec <pod> -- cat /config/config.json
```

Environment variables injected:
```bash
kubectl exec <pod> -- printenv | grep APP_
APP_ENV=production
LOG_LEVEL=INFO
FEATURES_METRICS=true
```

**File:** `app_python/docs/lab12screens`

**Before pod deletion:**
```bash
curl http://.../visits
{"visits":10}
```

**Delete pod:**
```bash
kubectl delete pod my-app-system-info-api-xxxxx-aaaaa
```

**After new pod starts:**
```bash
curl http://.../visits
{"visits":10}
```

✅ Counter preserved across pod restart!

```bash
kubectl exec <pod> -- printenv | grep APP_
APP_ENV=development
LOG_LEVEL=DEBUG
```

### Screenshot 4: All Resources
**File:** `app_python/docs/lab12screens`

```bash
kubectl get all,cm,pvc,secret
```

Complete resource list showing ConfigMaps, PVC, and application resources.

---

## Multi-Environment Support

### Development (values-dev.yaml)

```yaml
replicaCount: 1
environment: development
logLevel: DEBUG
persistence:
  size: 50Mi
```

### Production (values-prod.yaml)

```yaml
replicaCount: 5
environment: production
logLevel: INFO
persistence:
  size: 200Mi
```

**Deployment:**
```bash
# Dev
helm install my-app-dev system-info-api -f values-dev.yaml

# Prod
helm install my-app-prod system-info-api -f values-prod.yaml
```

---

## ConfigMap vs Secret

### When to use ConfigMap:

✅ Non-sensitive configuration  
✅ Application settings  
✅ Feature flags  
✅ Environment-specific config  
✅ Public API endpoints  

**Examples:**
- Database connection string (host/port, NOT password)
- Log levels
- Feature toggles
- API base URLs

### When to use Secret:

✅ Passwords  
✅ API keys  
✅ Certificates  
✅ Tokens  
✅ Private keys  

**Examples:**
- Database passwords
- OAuth tokens
- TLS certificates
- SSH keys

### Key Differences:

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Encoding** | Plain text | Base64 |
| **Encryption** | No | Optional (etcd encryption) |
| **Use Case** | Configuration | Credentials |
| **Git Safe** | Yes (non-sensitive) | No (never commit) |

---

## Resource Management

### Configured Limits

**Default (values.yaml):**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

### Requests vs Limits

**Requests:**
- Guaranteed minimum resources
- Used for pod scheduling
- Ensures pod gets at least this much

**Limits:**
- Maximum allowed resources
- Prevents resource hogging
- Pod throttled/killed if exceeded

**Why 2x ratio (100m→200m, 128Mi→256Mi):**
- Allows burst capacity
- Common best practice
- Balances performance and protection

### Choosing Values

**CPU:**
- Monitor with: `kubectl top pods`
- Start with p95 usage + 50% headroom
- 100m = 0.1 CPU core

**Memory:**
- Monitor actual usage
- Add headroom for spikes
- Memory limit violations = OOMKilled

**For this app:**
- Lightweight Flask API
- Minimal processing
- 100m/128Mi appropriate

---

## Persistence Verification

### Test Procedure

1. **Generate visits:**
   ```bash
   for i in {1..10}; do curl http://app-url/; done
   ```

2. **Record count:**
   ```bash
   curl http://app-url/visits
   # {"visits":10}
   ```

3. **Delete pod:**
   ```bash
   kubectl delete pod <pod-name>
   ```

4. **Wait for new pod:**
   ```bash
   kubectl get pods -w
   ```

5. **Verify persistence:**
   ```bash
   curl http://app-url/visits
   # {"visits":10} ← Same value!
   ```

### Why It Works

- PVC survives pod deletion
- New pod mounts same volume
- File `/data/visits` intact
- Counter continues from last value

---

## Storage Best Practices

### Production Considerations

**Storage Classes:**
- Use appropriate storage class for cloud provider
- AWS: `gp3`, `io1` for performance
- GCP: `pd-ssd`, `pd-balanced`
- Azure: `managed-premium`

**Backup:**
- Regular snapshots of PVs
- Backup to external storage
- Test restore procedures

**Access Modes:**
- `ReadWriteOnce` (RWO): Single node (most common)
- `ReadWriteMany` (RWX): Multi-node (NFS, CephFS)
- `ReadOnlyMany` (ROX): Shared read-only

**Reclaim Policy:**
- `Retain`: Keep volume after PVC deletion (manual cleanup)
- `Delete`: Auto-delete volume (default, risky)
- Production: Use `Retain` for important data

---

## Challenges & Solutions

### Challenge 1: ConfigMap Not Loading

**Problem:** Environment variables not appearing in pod.

**Solution:**
- Ensure `envFrom` in deployment template
- Verify ConfigMap created: `kubectl get cm`
- Check pod spec: `kubectl describe pod`

### Challenge 2: File Not Persisting

**Problem:** Visits counter resets on pod restart.

**Solution:**
- Verify PVC is Bound: `kubectl get pvc`
- Check volume mount: `kubectl describe pod`
- Ensure app writes to `/data` (mounted path)

### Challenge 3: Permission Denied

**Problem:** App can't write to `/data/visits`.

**Solution:**
- Check file permissions in container
- PVC mounted with correct permissions by default
- Ensure app creates directory: `mkdir -p /data`

---

## Summary

### Accomplishments

✅ **Application Enhanced:**
- Visits counter implementation
- File-based persistence
- New `/visits` endpoint

✅ **ConfigMaps:**
- File-based config (`config.json`)
- Environment variable injection
- Multi-environment support

✅ **Persistent Storage:**
- PVC for data persistence
- Verified across pod restarts
- Proper volume mounting

✅ **Production Ready:**
- Resource limits configured
- ConfigMap vs Secret understanding
- Storage best practices

### Key Learnings

**ConfigMaps:**
- Decouple config from code
- Same image, different environments
- Easy to update without rebuild

**PersistentVolumes:**
- Data survives pod lifecycle
- Essential for stateful apps
- Choose appropriate access mode

**Helm Templating:**
- `.Files.Get` for file inclusion
- Conditional volumes (`if .Values.persistence.enabled`)
- Values override pattern

---

## File Structure

```
k8s/system-info-api/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
├── files/
│   └── config.json          # Application config
└── templates/
    ├── deployment.yaml       # Updated with volumes
    ├── service.yaml
    ├── configmap.yaml        # NEW: Config + env
    ├── pvc.yaml              # NEW: Persistent storage
    ├── _helpers.tpl
    └── NOTES.txt
```

---

**Lab Completed:** March 27, 2026  
**Status:** ✅ All tasks completed  
**Persistence:** ✅ Verified  
**ConfigMaps:** ✅ Working
