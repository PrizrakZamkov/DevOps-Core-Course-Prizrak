# Lab 09 — Kubernetes Fundamentals

**Student:** PrizrakZamkov on github (Stanislav Delyukov)
**Date:** 2026-03-26  
**Points:** all
screenshots: app_python\docs\lab9 screens

---

## 1. Architecture Overview

### Deployment Summary

**Cluster:** minikube v1.38.1, Kubernetes v1.35.1  
**Pods:** 5 replicas (system-info-api-585bf77b68-{lvl55, w69fm, wzjgw, rhtzk, xbmnn})  
**Service:** NodePort (ClusterIP: 10.99.92.159, NodePort: 30080)  
**Image:** prizrakzamkov/system-info-api:latest (SHA: f220c8022df...)

---

## 2. Deployment Evidence

### Cluster Status

```bash
$ kubectl get nodes
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   2m24s   v1.35.1
```

### Initial Deployment (3 replicas)

```bash
$ kubectl apply -f deployment.yml
deployment.apps/system-info-api created

$ kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
system-info-api-585bf77b68-lvl55   1/1     Running   0          30s
system-info-api-585bf77b68-w69fm   1/1     Running   0          30s
system-info-api-585bf77b68-wzjgw   1/1     Running   0          30s
```

### Service Creation

```bash
$ kubectl apply -f service.yml
service/system-info-api-service created

$ kubectl get services
NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes                ClusterIP   10.96.0.1      <none>        443/TCP        4m32s
system-info-api-service   NodePort    10.99.92.159   <none>        80:30080/TCP   6s
```

### Scaling to 5 Replicas

```bash
$ kubectl apply -f deployment.yml  # replicas: 5
deployment.apps/system-info-api configured

$ kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
system-info-api-585bf77b68-lvl55   1/1     Running   0          4m33s
system-info-api-585bf77b68-rhtzk   1/1     Running   0          28s
system-info-api-585bf77b68-w69fm   1/1     Running   0          4m33s
system-info-api-585bf77b68-wzjgw   1/1     Running   0          4m33s
system-info-api-585bf77b68-xbmnn   1/1     Running   0          28s
```

✅ **All 5 pods Running, 0 Restarts**

### Complete Resources

```bash
$ kubectl get all
NAME                                   READY   STATUS    RESTARTS   AGE
pod/system-info-api-585bf77b68-lvl55   1/1     Running   0          7m1s
pod/system-info-api-585bf77b68-rhtzk   1/1     Running   0          2m56s
pod/system-info-api-585bf77b68-w69fm   1/1     Running   0          7m1s
pod/system-info-api-585bf77b68-wzjgw   1/1     Running   0          7m1s
pod/system-info-api-585bf77b68-xbmnn   1/1     Running   0          2m56s

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/kubernetes                ClusterIP   10.96.0.1      <none>        443/TCP        10m
service/system-info-api-service   NodePort    10.99.92.159   <none>        80:30080/TCP   5m50s

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/system-info-api   5/5     5            5           7m1s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/system-info-api-585bf77b68   5         5         5       7m1s
```

### Pod Details

```bash
$ kubectl describe pod system-info-api-585bf77b68-lvl55
Name:             system-info-api-585bf77b68-lvl55
Status:           Running
IP:               10.244.0.5
Containers:
  system-info-api:
    Image:          prizrakzamkov/system-info-api:latest
    Port:           6000/TCP
    State:          Running
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     200m
      memory:  256Mi
    Requests:
      cpu:      100m
      memory:   128Mi
    Liveness:   http-get http://:6000/health delay=10s period=10s
    Readiness:  http-get http://:6000/health delay=5s period=5s
    Environment:
      HOST:  0.0.0.0
      PORT:  6000
QoS Class:  Burstable
Events:
  Normal  Pulled     7m47s  Successfully pulled image in 13.674s
  Normal  Created    7m47s  Container created
  Normal  Started    7m47s  Container started
```

### Application Logs

```bash
$ kubectl logs -l app=system-info-api --tail=10
2026-03-26 20:28:13,232 [INFO] werkzeug: 10.244.0.1 - - [26/Mar/2026 20:28:13] "GET /health HTTP/1.1" 200 -
2026-03-26 20:28:15,247 [INFO] werkzeug: 10.244.0.1 - - [26/Mar/2026 20:28:15] "GET /health HTTP/1.1" 200 -
```

✅ **Health checks passing on all pods**

---

## 3. Configuration Rationale

### Deployment

**Replicas: 5**
- High availability
- Load distribution
- Fault tolerance

**Resources:**
- Requests: 100m CPU, 128Mi RAM (guaranteed minimum)
- Limits: 200m CPU, 256Mi RAM (maximum allowed)
- Appropriate for lightweight Flask app

**Health Probes:**
- Liveness: Restarts crashed containers (delay=10s, period=10s)
- Readiness: Removes unhealthy pods from service (delay=5s, period=5s)
- Both use `/health` endpoint

**Rolling Update:**
- maxSurge: 1 (one extra pod during update)
- maxUnavailable: 0 (zero downtime)

### Service

**Type:** NodePort
- Exposes service externally for local dev
- ClusterIP: 10.99.92.159 (internal)
- NodePort: 30080 (external)
- Port mapping: 80 → 6000

---

## 4. Operations Performed

### Initial Deploy
```bash
kubectl apply -f deployment.yml
kubectl apply -f service.yml
```

### Scaling
```bash
# Edit deployment.yml: replicas 3 → 5
kubectl apply -f deployment.yml
kubectl get pods -w  # Watch scaling
```

### Monitoring
```bash
kubectl get all
kubectl logs -l app=system-info-api --tail=20
kubectl describe pod <pod-name>
```

---

## 5. Challenges & Solutions

**Challenge:** minikube start failures  
**Solution:** `minikube delete` then fresh start

**Challenge:** Rollback history empty  
**Reason:** Scaling doesn't create new revision (only spec changes do)

**Challenge:** Service access from WSL  
**Solution:** Used minikube tunnel

---

## Summary

**Deployed:** 5-replica Kubernetes deployment  
**Service:** NodePort with external access  
**Health:** All probes passing, 0 restarts  
**Status:** ✅ Production-ready configuration

---

**Lab Completed:** March 26, 2026  
**All Tasks:** ✅ Completed
