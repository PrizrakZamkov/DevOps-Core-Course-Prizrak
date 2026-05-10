# StatefulSet - Lab 15

## Overview

StatefulSet is used when pods need stable identity and stable storage.

For this project the visits counter writes to:

```text
/data/visits
```

With a Deployment, pods can share one PVC or be replaced with random names. With StatefulSet, every pod gets:

- stable pod name: `system-info-stateful-system-info-api-0`
- stable DNS identity through headless service
- stable PVC from `volumeClaimTemplates`

## Deployment vs StatefulSet

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| Pod names | random suffix | ordered suffix `-0`, `-1`, `-2` |
| Storage | shared or manually attached | per-pod PVC |
| Scaling | any order | ordered by default |
| Network identity | service load balancing | stable DNS per pod |
| Best use | stateless apps | databases, queues, stateful apps |

## Headless Service

File:

```text
k8s/system-info-api/templates/headless-service.yaml
```

The headless service uses:

```yaml
clusterIP: None
```

DNS pattern:

```text
<pod-name>.<headless-service>.<namespace>.svc.cluster.local
```

Example:

```text
system-info-stateful-system-info-api-0.system-info-stateful-system-info-api-headless.stateful.svc.cluster.local
```

## StatefulSet Template

File:

```text
k8s/system-info-api/templates/statefulset.yaml
```

Important parts:

```yaml
serviceName: system-info-stateful-system-info-api-headless
podManagementPolicy: OrderedReady
volumeClaimTemplates:
  - metadata:
      name: data-volume
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 100Mi
```

## Deploy

```bash
helm upgrade --install system-info-stateful k8s/system-info-api \
  -n stateful --create-namespace \
  -f k8s/system-info-api/values-statefulset.yaml
```

Or through ArgoCD:

```bash
kubectl apply -f k8s/argocd/application-statefulset.yaml
```

## Resource Verification

```bash
kubectl get po,sts,svc,pvc -n stateful
```

Expected:

```text
pod/system-info-stateful-system-info-api-0
pod/system-info-stateful-system-info-api-1
pod/system-info-stateful-system-info-api-2

statefulset.apps/system-info-stateful-system-info-api

service/system-info-stateful-system-info-api
service/system-info-stateful-system-info-api-headless

persistentvolumeclaim/data-volume-system-info-stateful-system-info-api-0
persistentvolumeclaim/data-volume-system-info-stateful-system-info-api-1
persistentvolumeclaim/data-volume-system-info-stateful-system-info-api-2
```

## DNS Test

Exec into first pod:

```bash
kubectl exec -it system-info-stateful-system-info-api-0 -n stateful -- /bin/sh
```

Resolve another pod:

```bash
nslookup system-info-stateful-system-info-api-1.system-info-stateful-system-info-api-headless.stateful.svc.cluster.local
```

Expected:

```text
Name: system-info-stateful-system-info-api-1.system-info-stateful-system-info-api-headless.stateful.svc.cluster.local
Address: <pod-ip>
```

## Per-Pod Storage Test

Forward each pod separately:

```bash
kubectl port-forward pod/system-info-stateful-system-info-api-0 -n stateful 8080:6000
kubectl port-forward pod/system-info-stateful-system-info-api-1 -n stateful 8081:6000
kubectl port-forward pod/system-info-stateful-system-info-api-2 -n stateful 8082:6000
```

Call pods different numbers of times:

```bash
curl http://localhost:8080/
curl http://localhost:8080/
curl http://localhost:8081/
```

Check counts:

```bash
curl http://localhost:8080/visits
curl http://localhost:8081/visits
curl http://localhost:8082/visits
```

Expected:

```text
pod-0: {"visits":2}
pod-1: {"visits":1}
pod-2: {"visits":0}
```

This proves every pod has its own storage.

## Persistence Test

Check pod 0 count:

```bash
kubectl exec system-info-stateful-system-info-api-0 -n stateful -- cat /data/visits
```

Delete pod:

```bash
kubectl delete pod system-info-stateful-system-info-api-0 -n stateful
```

Wait for restart:

```bash
kubectl get pods -n stateful -w
```

Check count again:

```bash
kubectl exec system-info-stateful-system-info-api-0 -n stateful -- cat /data/visits
```

Expected:

```text
same value as before deletion
```

The pod is recreated with the same name and same PVC.

## Bonus: Update Strategies

### Partitioned Rolling Update

File:

```text
k8s/system-info-api/values-statefulset-partition.yaml
```

Configuration:

```yaml
statefulset:
  updateStrategy:
    type: RollingUpdate
    partitioned: true
    partition: 2
```

Only pods with ordinal `>= 2` update. With 3 replicas, only pod `-2` updates.

### OnDelete Strategy

File:

```text
k8s/system-info-api/values-statefulset-ondelete.yaml
```

Configuration:

```yaml
statefulset:
  updateStrategy:
    type: OnDelete
```

Pods do not update automatically. They update only after manual deletion.

Useful when:

- every instance needs manual maintenance
- update order must be controlled by an operator
- data safety is more important than speed

## Commands Reference

```bash
kubectl get statefulset -n stateful
kubectl describe statefulset system-info-stateful-system-info-api -n stateful
kubectl get pods -n stateful -o wide
kubectl get pvc -n stateful
kubectl get svc -n stateful
kubectl logs system-info-stateful-system-info-api-0 -n stateful
kubectl delete pod system-info-stateful-system-info-api-0 -n stateful
```

## Summary

StatefulSet gives stable pod identity and stable storage. It is the right controller when the application instance itself owns state.

For `system-info-api`, each pod can keep its own `/data/visits` file and recover it after pod recreation.
