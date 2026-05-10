# Fly.io Edge Deployment - Lab 17

## Overview

This lab prepares `system-info-api` for Fly.io edge deployment.

Fly.io is a PaaS platform that runs apps on Fly Machines close to users. It is simpler than managing Kubernetes directly, but gives less low-level cluster control.

## App Configuration

Fly config:

```text
app_python/fly.toml
```

Important settings:

```toml
app = "prizrak-system-info-api"
primary_region = "ams"

[http_service]
  internal_port = 6000
  force_https = true

[[mounts]]
  source = "system_info_data"
  destination = "/data"
```

The Flask app now reads `HOST`, `PORT`, and `DEBUG` from environment variables.

## Setup

Install `flyctl` on Windows PowerShell:

```powershell
pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
```

Login:

```bash
fly auth login
fly auth whoami
fly version
```

## Launch and Deploy

```bash
cd app_python
fly launch --no-deploy
fly deploy
```

If app name is taken, edit `app_python/fly.toml` and choose a unique name:

```toml
app = "your-unique-app-name"
```

Open:

```bash
fly open
```

Useful endpoints:

```text
https://<app-name>.fly.dev/
https://<app-name>.fly.dev/health
https://<app-name>.fly.dev/metrics
https://<app-name>.fly.dev/visits
```

## Verify Deployment

```bash
fly status
fly logs
fly checks list
fly releases
```

Expected:

```text
Machine is started
Health check /health is passing
App responds over HTTPS
```

## Multi-Region Deployment

Regions used for lab:

| Region | Location |
|--------|----------|
| `ams` | Amsterdam |
| `iad` | Virginia, USA |
| `sin` | Singapore |

Commands:

```bash
fly regions list
fly regions add iad sin
fly scale count 2 --region ams
fly machines list
fly status
fly ping
```

Expected:

```text
machines are visible in multiple regions
primary region has 2 machines after scale command
```

## Secrets

Set at least two secrets:

```bash
fly secrets set APP_SECRET_KEY="change-me" API_KEY="secret123"
fly secrets list
```

Secrets are injected as environment variables into the running machine.

Verify:

```bash
fly ssh console
printenv | grep -E "APP_SECRET_KEY|API_KEY"
```

## Persistence

The app stores visit count at:

```text
/data/visits
```

Fly volume:

```bash
fly volumes create system_info_data --size 1 --region ams
fly deploy
```

Verify:

```bash
curl https://<app-name>.fly.dev/
curl https://<app-name>.fly.dev/visits

fly ssh console
cat /data/visits
```

Expected:

```text
visit counter survives deployments and machine restarts
```

## Monitoring and Operations

Dashboard:

```text
https://fly.io/dashboard
```

Check:

- Machines tab
- Metrics tab
- Volumes tab
- Deployments/releases
- Logs

Commands:

```bash
fly logs
fly status
fly releases
fly checks list
fly deploy --strategy rolling
```

## Kubernetes vs Fly.io

| Aspect | Kubernetes | Fly.io |
|--------|------------|--------|
| Setup complexity | High: cluster, nodes, ingress, storage | Low: app config and deploy |
| Deployment speed | Powerful but more YAML | Fast deploy with `fly deploy` |
| Global distribution | Needs multi-cluster or complex setup | Built in with regions |
| Cost for small apps | Can be expensive/overkill | Good for small global apps |
| Learning curve | Steep | Much easier |
| Control/flexibility | Maximum control | Less control, simpler operations |
| Best use case | Complex platforms and internal systems | Small/medium apps needing global edge |

## Recommendation

Use Kubernetes when:

- many services need shared platform features
- custom networking/storage/security is required
- team needs maximum control

Use Fly.io when:

- app is Dockerized and needs fast global deployment
- small team wants less infrastructure management
- edge latency matters

For `system-info-api`, Fly.io is a good fit because the app is small, containerized, HTTP-based, and can use a simple volume for visits persistence.

## Screenshots to Capture Live

After logging in and deploying:

1. Fly dashboard app overview
2. Machines list with regions
3. Metrics page
4. Volumes page
5. Successful `/health` response

## Command Reference

```bash
fly auth login
fly version
fly launch --no-deploy
fly deploy
fly open
fly status
fly logs
fly regions add iad sin
fly scale count 2 --region ams
fly machines list
fly volumes create system_info_data --size 1 --region ams
fly secrets set APP_SECRET_KEY="change-me" API_KEY="secret123"
fly releases
fly checks list
```
