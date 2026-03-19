# Lab 08 — Metrics & Monitoring with Prometheus

**Student:** PrizrakZamkov (Stanislav Delyukov) 
**Date:** 2026-03-12  
**Points:** 10? + 0 bonus

---

## Overview

This lab extends the observability stack from Lab 07 by adding Prometheus metrics collection and visualization. We now have complete observability with both logs (Loki) and metrics (Prometheus) feeding into Grafana dashboards.

**Infrastructure:**
- **VM:** 93.77.179.128 (Yandex Cloud, Ubuntu 24.04)
- **Existing Stack:** Loki 3.0 + Promtail 3.0 + Grafana 12.3 (from Lab 07)
- **New:** Prometheus 3.0.0

**Key Features Implemented:**
- Prometheus metrics endpoint in Python application
- Counter, Histogram, and Gauge metric types
- RED method implementation (Rate, Errors, Duration)
- Prometheus scraping 4 targets (self, Loki, Grafana, app)
- Grafana dashboard with 6 metric panels
- 15-day metric retention with 10GB limit
- Health checks and resource limits

---

## 1. Architecture

### Complete Observability Stack

```
┌──────────────────────────────────────────────────────────────────┐
│                        Docker Host (VM)                           │
│                                                                    │
│  ┌──────────────┐     ┌─────────────┐      ┌──────────────────┐ │
│  │ Application  │────▶│  Promtail   │─────▶│       Loki       │ │
│  │ (Flask App)  │logs │(Log Collector)│push│  (Log Storage)   │ │
│  │              │     └─────────────┘      └──────────────────┘ │
│  │ Port: 5000   │                                    │           │
│  │              │                                    │           │
│  │ /metrics     │◀──scrape───┐                      │query      │
│  └──────────────┘             │                      ▼           │
│                               │              ┌──────────────────┐│
│  ┌──────────────┐             │              │     Grafana      ││
│  │     Loki     │◀──scrape────┤              │  (Visualization) ││
│  │              │             │              │                  ││
│  │ Port: 3100   │             │              │  - Loki DS       ││
│  │ /metrics     │             │              │  - Prometheus DS ││
│  └──────────────┘             │              │                  ││
│                               │              │  Port: 3000      ││
│  ┌──────────────┐             │              └────────┬─────────┘│
│  │   Grafana    │◀──scrape────┤                       │          │
│  │              │             │                       │          │
│  │ Port: 3000   │             │                       │query     │
│  │ /metrics     │             │                       ▼          │
│  └──────────────┘      ┌──────────────┐     ┌──────────────────┐│
│                        │  Prometheus  │◀────│   PromQL Queries ││
│                        │(Metrics Store)│     └──────────────────┘│
│                        │              │                          │
│                        │ Port: 9090   │                          │
│                        │ /metrics     │◀──scrape─┐               │
│                        └──────────────┘          │               │
│                               │                  │               │
│                               └──────────────────┘               │
│                                                                   │
│  Network: logging (bridge)                                       │
│  Volumes: loki-data, grafana-data, prometheus-data              │
└───────────────────────────────────────────────────────────────────┘
```

### Data Flow

**Logs (Lab 07):**
1. Application → JSON logs → stdout
2. Docker → captures logs
3. Promtail → scrapes → Loki
4. Grafana → queries Loki → displays logs

**Metrics (Lab 08):**
1. Application → exposes /metrics endpoint
2. Prometheus → scrapes every 15s
3. Prometheus → stores in TSDB
4. Grafana → queries Prometheus → displays metrics

**Integration:**
- Both Loki and Prometheus in Grafana
- Correlate logs with metrics
- Single pane of glass for observability

### Why Both Logs AND Metrics?

| Aspect | Logs (Lab 07) | Metrics (Lab 08) |
|--------|--------------|------------------|
| **What** | Individual events | Aggregated data |
| **When** | After it happened | Real-time trends |
| **Size** | Large (full context) | Small (numbers) |
| **Query** | Search by content | Math operations |
| **Use Case** | Debugging, investigation | Monitoring, alerting |

**Example:**
- **Metric:** "Error rate increased to 5%"
- **Log:** "User 12345 got 500 error on /api/order"

Together they answer: **What happened?** (metrics) and **Why?** (logs)

---

## 2. Application Instrumentation

### 2.1 Metrics Added

**File:** `app_python/app.py`

#### HTTP Request Counter

```python
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)
```

**Type:** Counter (only increases)  
**Labels:** method, endpoint, status  
**Purpose:** Track total requests by endpoint and status code

**Use cases:**
- Calculate request rate: `rate(http_requests_total[1m])`
- Error rate: `sum(rate(http_requests_total{status=~"5.."}[5m]))`
- Requests by endpoint: `sum by (endpoint) (http_requests_total)`

#### Request Duration Histogram

```python
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)
```

**Type:** Histogram (distribution of values)  
**Labels:** method, endpoint  
**Purpose:** Measure request latency distribution

**Buckets (default):**
`.005, .01, .025, .05, .075, .1, .25, .5, .75, 1.0, 2.5, 5.0, 7.5, 10.0, +Inf`

**Use cases:**
- 95th percentile latency: `histogram_quantile(0.95, ...)`
- Average duration: `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])`
- Slow requests (>1s): `http_request_duration_seconds_bucket{le="1.0"}`

#### Active Requests Gauge

```python
http_requests_in_progress = Gauge(
    'http_requests_in_progress',
    'HTTP requests currently being processed'
)
```

**Type:** Gauge (can go up and down)  
**Purpose:** Track concurrent requests

**Implementation:**
```python
@app.before_request
def before_request():
    http_requests_in_progress.inc()

@app.after_request
def after_request(response):
    http_requests_in_progress.dec()
    return response
```

**Use cases:**
- Current load monitoring
- Capacity planning
- Detect stuck requests (gauge stays high)

#### Endpoint-Specific Counter

```python
endpoint_calls = Counter(
    'devops_info_endpoint_calls',
    'Endpoint-specific call counter',
    ['endpoint']
)
```

**Type:** Counter  
**Purpose:** Track usage of specific API endpoints

**Use cases:**
- Most popular endpoints
- API usage patterns
- Feature adoption tracking

### 2.2 Instrumentation Implementation

**Timing Requests:**

```python
@app.before_request
def before_request():
    request.start_time = time.time()
    http_requests_in_progress.inc()

@app.after_request
def after_request(response):
    request_duration = time.time() - request.start_time
    
    # Normalize endpoint
    endpoint = request.path
    if endpoint not in ['/', '/health', '/metrics']:
        endpoint = 'other'
    
    # Record metrics
    http_requests_total.labels(
        method=request.method,
        endpoint=endpoint,
        status=response.status_code
    ).inc()
    
    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=endpoint
    ).observe(request_duration)
    
    http_requests_in_progress.dec()
    
    return response
```

**Key Points:**
- Start timer in `before_request`
- Calculate duration in `after_request`
- Normalize endpoints to prevent label explosion
- Use `.labels()` to specify label values

### 2.3 Metrics Endpoint

```python
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
```

**Output format (Prometheus exposition format):**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{endpoint="/",method="GET",status="200"} 45.0
http_requests_total{endpoint="/health",method="GET",status="200"} 12.0
http_requests_total{endpoint="other",method="GET",status="404"} 3.0

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{endpoint="/",le="0.005",method="GET"} 20.0
http_request_duration_seconds_bucket{endpoint="/",le="0.01",method="GET"} 42.0
http_request_duration_seconds_sum{endpoint="/",method="GET"} 1.234
http_request_duration_seconds_count{endpoint="/",method="GET"} 45.0

# HELP http_requests_in_progress HTTP requests currently being processed
# TYPE http_requests_in_progress gauge
http_requests_in_progress 0.0
```

### 2.4 Label Cardinality Best Practices

**Good labels (low cardinality):**
- endpoint: `/`, `/health`, `other` (3 values)
- method: `GET`, `POST`, `PUT`, etc. (5-10 values)
- status: `200`, `404`, `500`, etc. (10-20 values)

**Bad labels (high cardinality):**
- ❌ user_id: `12345`, `67890`, ... (thousands/millions)
- ❌ timestamp: `2026-03-12T10:30:45Z` (infinite)
- ❌ full_url: `/user/12345/order/67890` (infinite)

**Why it matters:**
- Each unique label combination = new time series
- High cardinality = memory explosion
- Rule: Keep total combinations < 10,000

**Our cardinality:**
```
http_requests_total{method, endpoint, status}
= 3 methods × 3 endpoints × 5 statuses = 45 time series ✅
```

---

## 3. Prometheus Configuration

### 3.1 Configuration File

**File:** `monitoring/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s      # How often to scrape targets
  evaluation_interval: 15s   # How often to evaluate rules

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'system-info-api'
    static_configs:
      - targets: ['system-info-api:6000']
    metrics_path: '/metrics'
```

### 3.2 Configuration Explained

**Global Settings:**
- `scrape_interval: 15s` - Prometheus pulls metrics every 15 seconds
- `evaluation_interval: 15s` - Evaluates recording/alerting rules every 15 seconds

**Scrape Configs:**

**Job:** prometheus (self-monitoring)
- Target: `localhost:9090`
- Metrics: Prometheus's own internal metrics
- Used to: Monitor Prometheus itself

**Job:** loki
- Target: `loki:3100`
- Metrics: Loki's internal metrics
- Used to: Monitor log ingestion rate, query performance

**Job:** grafana
- Target: `grafana:3000`
- Metrics: Grafana's internal metrics
- Used to: Monitor dashboard usage, data source queries

**Job:** system-info-api
- Target: `system-info-api:6000`
- Path: `/metrics` (custom endpoint)
- Metrics: Our application metrics
- Used to: Monitor app performance, requests, errors

### 3.3 Service Discovery vs Static Config

**Static Configuration (what we use):**
```yaml
static_configs:
  - targets: ['app:8000']
```
- Simple, explicit
- Good for fixed infrastructure
- Requires restart to add targets

**Service Discovery (production):**
```yaml
dns_sd_configs:
  - names: ['app.service.consul']
```
or
```yaml
kubernetes_sd_configs:
  - role: pod
```
- Dynamic, auto-discovers new instances
- No restart needed
- Better for cloud/containers

**Why static for this lab:**
- Fixed number of services
- Educational clarity
- Simpler to debug

### 3.4 Retention Configuration

**Docker Compose command flags:**
```yaml
command:
  - '--storage.tsdb.path=/prometheus'
  - '--storage.tsdb.retention.time=15d'
  - '--storage.tsdb.retention.size=10GB'
```

**Retention by time:**
- `15d` = 15 days
- After 15 days, old data deleted
- Balances history vs disk space

**Retention by size:**
- `10GB` maximum storage
- When limit reached, oldest data deleted
- Prevents disk full

**Whichever limit reached first triggers deletion.**

**Disk usage estimation:**
```
Application metrics: ~50 samples/sec × 50 metrics = 2500 samples/sec
Prometheus overhead: ~2 KB per sample
Per day: 2500 × 86400 × 2KB = ~432 MB/day
15 days: ~6.5 GB (well under 10GB limit)
```

---

## 4. Dashboard Walkthrough

### Dashboard: Application Metrics

**Panels:** 6  
**Data Source:** Prometheus  
**Refresh:** 30 seconds (auto)

**Screenshot:** See `monitoring/docs/screenshots/metrics-dashboard-full.png`

### Panel 1: Request Rate

**Type:** Time series  
**Query:**
```promql
rate(http_requests_total[1m])
```

**Explanation:**
- `rate()` - Calculate per-second rate
- `[1m]` - Over 1-minute window
- Shows requests per second

**What it shows:**
- Traffic patterns over time
- Sudden spikes or drops
- Baseline load

**Interpretation:**
- Flat line = steady traffic
- Spikes = bursts (deployments, traffic surges)
- Drop to zero = application down

### Panel 2: Request Duration p95

**Type:** Time series  
**Query:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Explanation:**
- `histogram_quantile(0.95, ...)` - Calculate 95th percentile
- 95% of requests faster than this value
- Uses histogram buckets

**What it shows:**
- Response time for 95% of requests
- Latency trends
- Performance degradation

**Interpretation:**
- Low values (< 100ms) = fast
- Increasing = performance problem
- Spikes = slow queries/overload

### Panel 3: Requests by Status

**Type:** Time series  
**Query:**
```promql
sum by (status) (rate(http_requests_total[1m]))
```

**Explanation:**
- `sum by (status)` - Group by status code
- Separate line for 200, 404, 500, etc.
- Per-second rate

**What it shows:**
- Success rate (2xx)
- Client errors (4xx)
- Server errors (5xx)

**Interpretation:**
- Mostly 2xx = healthy
- Increasing 4xx = bad requests
- Any 5xx = application errors

### Panel 4: Requests In Progress

**Type:** Stat (single value)  
**Query:**
```promql
http_requests_in_progress
```

**Explanation:**
- Current gauge value
- No rate/aggregation needed
- Instant snapshot

**What it shows:**
- Current concurrent requests
- Real-time load

**Interpretation:**
- 0 = idle
- Low (1-5) = normal load
- High (10+) = heavy load or stuck requests

### Panel 5: Error Rate

**Type:** Time series  
**Query:**
```promql
sum(rate(http_requests_total{status=~"4..|5.."}[1m]))
```

**Explanation:**
- `status=~"4..|5.."` - Regex: 4xx or 5xx
- `sum()` - Total errors
- Per-second rate

**What it shows:**
- Combined error rate
- Both client and server errors

**Interpretation:**
- Zero = no errors
- Non-zero = issues
- Sudden spike = incident

### Panel 6: Total Requests

**Type:** Stat (single value)  
**Query:**
```promql
sum(http_requests_total)
```

**Explanation:**
- Sum of all counter values
- Lifetime total since app start
- Not a rate (absolute count)

**What it shows:**
- Total requests served
- Ever-increasing

**Interpretation:**
- Shows overall usage
- Resets to zero on app restart

---

## 5. PromQL Examples

### Basic Queries

**Instant vector (current value):**
```promql
http_requests_in_progress
```

**Range vector (values over time):**
```promql
http_requests_total[5m]
```

### Filtering

**By label:**
```promql
http_requests_total{endpoint="/health"}
```

**Regex match:**
```promql
http_requests_total{status=~"5.."}
```

**Not equal:**
```promql
http_requests_total{endpoint!="/metrics"}
```

### Aggregations

**Sum:**
```promql
sum(http_requests_total)
```

**Sum by label:**
```promql
sum by (endpoint) (http_requests_total)
```

**Count:**
```promql
count(up)
```

**Average:**
```promql
avg(http_requests_in_progress)
```

### Rate and Increase

**Per-second rate:**
```promql
rate(http_requests_total[5m])
```

**Total increase:**
```promql
increase(http_requests_total[1h])
```

### Math Operations

**Error percentage:**
```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) 
/ 
sum(rate(http_requests_total[5m])) 
* 100
```

**Success rate:**
```promql
sum(rate(http_requests_total{status="200"}[5m])) 
/ 
sum(rate(http_requests_total[5m]))
```

### Histogram Percentiles

**p50 (median):**
```promql
histogram_quantile(0.5, rate(http_request_duration_seconds_bucket[5m]))
```

**p95:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**p99:**
```promql
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### RED Method Queries

**Rate (requests per second):**
```promql
sum(rate(http_requests_total[1m]))
```

**Errors (error percentage):**
```promql
sum(rate(http_requests_total{status=~"5.."}[1m])) 
/ 
sum(rate(http_requests_total[1m])) 
* 100
```

**Duration (average latency):**
```promql
rate(http_request_duration_seconds_sum[5m]) 
/ 
rate(http_request_duration_seconds_count[5m])
```

---

## 6. Production Setup

### 6.1 Health Checks

**Prometheus:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

**Verification:**
```bash
curl http://93.77.179.128:9090/-/healthy
# Returns: Prometheus Server is Healthy.
```

### 6.2 Resource Limits

**Prometheus:**
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

**Why these limits:**
- 1 CPU: Enough for 4 targets × 15s scraping
- 1GB RAM: Handles 15-day retention at our scale
- Prevents memory leaks from consuming entire VM

**Resource usage observed:**
```
Prometheus: ~300MB RAM, ~10% CPU
Loki: ~200MB RAM, ~5% CPU
Grafana: ~150MB RAM, ~3% CPU
Total: ~650MB RAM, ~18% CPU (plenty of headroom on 2GB VM)
```

### 6.3 Data Persistence

**Volumes:**
```yaml
volumes:
  prometheus-data:
    name: prometheus-data
  loki-data:
    name: loki-data
  grafana-data:
    name: grafana-data
```

**Test persistence:**
```bash
# Create dashboard
docker compose down
docker compose up -d
# Dashboard still exists ✅
```

**Backup strategy (production):**
```bash
# Backup Prometheus data
docker run --rm -v prometheus-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Backup Grafana dashboards
docker run --rm -v grafana-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup.tar.gz -C /data .
```

### 6.4 Security Considerations

**Metrics endpoint exposure:**
- `/metrics` is public (no auth)
- Contains sensitive data (request patterns, error rates)
- Production: Use network policies or auth

**Prometheus UI:**
- Port 9090 exposed (for this lab)
- Production: Restrict to internal network or VPN
- Or use Grafana as only interface

**Current setup:**
- Development/learning environment
- Acceptable security posture for lab
- Would need hardening for production

### 6.5 Retention Policies

**Prometheus:**
- Time: 15 days
- Size: 10GB
- Whichever first

**Loki:**
- Time: 7 days (from Lab 07)
- Compactor runs every 10 minutes

**Why different retentions:**
- Metrics (15d): Smaller data, good for trends
- Logs (7d): Larger data, mainly for recent debugging

**Adjusting retention:**
```yaml
# Prometheus - docker-compose.yml
command:
  - '--storage.tsdb.retention.time=30d'  # Change to 30 days

# Loki - loki/config.yml
limits_config:
  retention_period: 336h  # 14 days
```

---

## 7. Testing Results

### 7.1 Service Health

**Command:**
```bash
docker compose ps
```

**Output:**
```
NAME              IMAGE                                  STATUS
grafana           grafana/grafana:12.3.1                 Up (healthy)
loki              grafana/loki:3.0.0                     Up (healthy)
promtail          grafana/promtail:3.0.0                 Up
prometheus        prom/prometheus:v3.0.0                 Up (healthy)
system-info-api   prizrakzamkov/system-info-api:latest   Up
```

**Evidence:** See `screenshots/docker-compose-ps.png`

### 7.2 Prometheus Targets

**URL:** http://93.77.179.128:9090/targets

**All targets UP:**
- prometheus (localhost:9090) - UP
- loki (loki:3100) - UP
- grafana (grafana:3000) - UP
- system-info-api (system-info-api:6000) - UP

**Evidence:** See `screenshots/prometheus-targets-up.png`

### 7.3 Grafana Data Sources

**Loki:**
- URL: http://loki:3100
- Status: ✅ Working

**Prometheus:**
- URL: http://prometheus:9090
- Status: ✅ Working

**Evidence:** See `screenshots/grafana-datasources.png`

### 7.4 Metrics Availability

**Command:**
```bash
curl http://93.77.179.128:5000/metrics | head -20
```

**Output:**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{endpoint="/",method="GET",status="200"} 127.0
http_requests_total{endpoint="/health",method="GET",status="200"} 34.0
http_requests_total{endpoint="other",method="GET",status="404"} 15.0

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{endpoint="/",le="0.005",method="GET"} 98.0
http_request_duration_seconds_bucket{endpoint="/",le="0.01",method="GET"} 125.0
...
```

**Evidence:** See `screenshots/metrics-endpoint.png`

### 7.5 Dashboard with Live Data

**Test scenario:**
```bash
# Generate traffic
for i in {1..100}; do curl http://93.77.179.128:5000/; done
for i in {1..20}; do curl http://93.77.179.128:5000/health; done
for i in {1..10}; do curl http://93.77.179.128:5000/404; done
```

**Dashboard shows:**
- Request Rate: Spike to ~10 req/sec during test
- Duration p95: ~0.008s (8ms)
- Status codes: Mostly 200, some 404
- Requests in Progress: 0 (after test completes)
- Error Rate: ~8% during test (10 errors / 130 total)
- Total Requests: 176 lifetime

**Evidence:** See `screenshots/dashboard-with-load.png`

---

## 8. Challenges & Solutions

### Challenge 1: Prometheus Image Version

**Problem:**
Initially used `prom/prometheus:latest` which pulled v2.x

**Solution:**
Explicitly specify version: `prom/prometheus:v3.0.0`

**Lesson:**
Always pin versions in production to avoid surprise updates.

### Challenge 2: Port 9090 Not Accessible

**Problem:**
Prometheus UI not reachable from browser.

**Root Cause:**
Yandex Cloud Security Group blocking port 9090.

**Solution:**
Added ingress rule in Security Group:
- Port: 9090
- Protocol: TCP
- CIDR: 0.0.0.0/0

**Prevention:**
Open all needed ports before deployment.

### Challenge 3: Metrics Not Appearing in Prometheus

**Problem:**
Targets showed UP but no data in queries.

**Root Cause:**
Application metrics endpoint returned empty response initially.

**Debugging:**
```bash
curl http://localhost:5000/metrics
# Initially returned: (empty)

# After fix:
curl http://localhost:5000/metrics
# Returns: # HELP http_requests_total...
```

**Solution:**
Fixed Flask route to properly return `generate_latest()`.

### Challenge 4: High Cardinality Warning

**Problem:**
Initially used full URL path as label:
```python
http_requests_total{endpoint="/user/12345"}
http_requests_total{endpoint="/user/67890"}
# ... thousands of unique time series
```

**Root Cause:**
Every unique path creates new time series.

**Solution:**
Normalize endpoints:
```python
endpoint = request.path
if endpoint not in ['/', '/health', '/metrics']:
    endpoint = 'other'
```

**Lesson:**
Keep label cardinality low (< 10,000 combinations).

### Challenge 5: Dashboard Empty After Creation

**Problem:**
Created dashboard but all panels empty.

**Root Cause:**
No traffic to application yet (zero metrics).

**Solution:**
Generated test traffic with curl commands:
```bash
for i in {1..50}; do curl http://93.77.179.128:5000/; done
```

**Lesson:**
Need actual traffic to generate metrics data.

---

## Summary

### Accomplishments

**Technical:**
- ✅ Added prometheus_client to Python application
- ✅ Implemented Counter, Histogram, Gauge metrics
- ✅ Created `/metrics` endpoint
- ✅ Deployed Prometheus 3.0.0
- ✅ Configured 4 scrape targets
- ✅ Added Prometheus data source to Grafana
- ✅ Created 6-panel metrics dashboard
- ✅ Implemented RED method (Rate, Errors, Duration)
- ✅ Set 15-day retention with 10GB limit
- ✅ All services healthy with health checks

**Observability Stack:**
- Logs: Loki (Lab 07)
- Metrics: Prometheus (Lab 08)
- Visualization: Grafana (both labs)
- Complete observability achieved

### Skills Gained

- Prometheus metric types and when to use them
- Application instrumentation best practices
- Label cardinality management
- PromQL query language
- Histogram percentile calculations
- RED method for service monitoring
- Prometheus TSDB configuration
- Retention policy planning

### Key Learnings

**Metrics vs Logs:**
- Metrics: "System is slow" (quantitative)
- Logs: "Why is it slow?" (qualitative)
- Both needed for complete picture

**Instrumentation:**
- Measure what matters (RED method)
- Keep cardinality low
- Use appropriate metric types
- Don't over-instrument

**Operations:**
- Health checks catch issues early
- Resource limits prevent overload
- Retention balances cost and utility
- Persistence critical for dashboards

### Time Investment

- Application instrumentation: 1.5 hours
- Prometheus setup: 1 hour
- Dashboard creation: 1.5 hours
- Testing and debugging: 1 hour
- Documentation: 1.5 hours

**Total: ~6.5 hours**

### Production Readiness

**Current State:**
- ✅ Health checks
- ✅ Resource limits
- ✅ Data persistence
- ✅ Retention policies
- ✅ Multiple data sources

**Production TODO:**
- [ ] Add alerting rules
- [ ] Implement service discovery
- [ ] Add authentication to Prometheus UI
- [ ] Set up remote storage (Thanos/Cortex)
- [ ] Configure alert manager
- [ ] Add SLO/SLI tracking
- [ ] Implement distributed tracing (Jaeger)

---

## Appendix

### A. PromQL Cheat Sheet

```promql
# Instant vectors
http_requests_total                    # Current value
up{job="prometheus"}                   # With filter

# Range vectors
http_requests_total[5m]                # Last 5 minutes

# Rate
rate(http_requests_total[1m])          # Per-second rate
irate(http_requests_total[1m])         # Instant rate

# Aggregation
sum(http_requests_total)               # Total
sum by (status) (http_requests_total)  # Group by
avg(http_requests_in_progress)         # Average
max(http_request_duration_seconds)     # Maximum

# Math
http_requests_total * 2                # Multiply
sum(a) / sum(b)                       # Division

# Functions
abs(http_requests_in_progress)         # Absolute value
ceil(rate(http_requests_total[1m]))    # Round up
floor(rate(http_requests_total[1m]))   # Round down
round(rate(http_requests_total[1m]))   # Round

# Histogram
histogram_quantile(0.95, ...)          # 95th percentile
```

### B. Useful Commands

```bash
# Check Prometheus health
curl http://localhost:9090/-/healthy

# Query API directly
curl 'http://localhost:9090/api/v1/query?query=up'

# Check targets
curl http://localhost:9090/api/v1/targets

# Application metrics
curl http://localhost:5000/metrics

# Reload Prometheus config (if --web.enable-lifecycle)
curl -X POST http://localhost:9090/-/reload

# Check Prometheus TSDB stats
curl http://localhost:9090/api/v1/status/tsdb

# Grafana API - list dashboards
curl -H "Authorization: Bearer <token>" \
  http://localhost:3000/api/search?type=dash-db
```

### C. File Structure

```
monitoring/
├── docker-compose.yml
├── .env
├── .gitignore
├── loki/
│   └── config.yml
├── promtail/
│   └── config.yml
├── prometheus/
│   └── prometheus.yml          # New in Lab 08
└── docs/
    ├── LAB07.md
    ├── LAB08.md                # This file
    └── screenshots/
        ├── metrics-endpoint.png
        ├── prometheus-targets-up.png
        ├── grafana-datasources.png
        ├── dashboard-full.png
        ├── dashboard-with-load.png
        └── docker-compose-ps.png
```

### D. Metric Naming Conventions

**Format:** `<namespace>_<name>_<unit>`

**Good examples:**
- `http_requests_total` (counter, requests)
- `http_request_duration_seconds` (histogram, seconds)
- `http_requests_in_progress` (gauge, current count)
- `process_cpu_seconds_total` (counter, seconds)

**Bad examples:**
- ❌ `httpRequests` (camelCase)
- ❌ `http-requests-total` (hyphens)
- ❌ `requests` (too generic)
- ❌ `http_request_duration_ms` (use seconds, not ms)

**Units:**
- Time: `_seconds`
- Bytes: `_bytes`
- Percentage: `_ratio` (0-1, not 0-100)
- Total: `_total` suffix for counters

---

**Lab Completed:** March 12, 2026  
**Status:** ✅ All tasks completed successfully  
**Points Earned:** 10/10 (main tasks)  
**Bonus:** Not attempted
