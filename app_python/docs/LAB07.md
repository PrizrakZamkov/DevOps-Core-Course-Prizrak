# Lab 07 — Observability & Logging with Loki Stack

**Student:** PrizrakZamkov (github) Stanislav Delyukov  
**Date:** 2026-03-11  
**Points:** ?

---

## Overview

This lab implements a centralized logging stack using Grafana Loki 3.0, Promtail 3.0, and Grafana 12.3 to aggregate and visualize logs from containerized applications.

**Infrastructure:**
- **VM:** 93.77.179.128 (Yandex Cloud, Ubuntu 24.04)
- **Stack:** Loki 3.0 + Promtail 3.0 + Grafana 12.3
- **Application:** System Info API (Python Flask with JSON logging)

**Key Features Implemented:**
- TSDB storage backend (10x faster queries vs boltdb)
- Docker service discovery with Promtail
- Structured JSON logging in application
- Interactive Grafana dashboard with 4 panels
- 7-day log retention policy
- Resource limits and health checks

---

## 1. Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Docker Host (VM)                        │
│                                                                   │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────────┐ │
│  │ Application  │      │   Promtail   │      │    Grafana    │ │
│  │ (Flask App)  │─────▶│ (Log Collector)────▶│ (Visualization)│ │
│  │              │ logs │              │ push │               │ │
│  │ Port: 5000   │      │ Port: 9080   │      │  Port: 3000   │ │
│  └──────────────┘      └──────┬───────┘      └───────┬───────┘ │
│                               │                      │         │
│                               │ scrape               │ query   │
│                               ▼                      ▼         │
│                        ┌──────────────┐                        │
│                        │     Loki     │                        │
│                        │ (Log Storage)│                        │
│                        │              │                        │
│                        │  Port: 3100  │                        │
│                        └──────────────┘                        │
│                                                                  │
│  Network: logging (bridge)                                      │
│  Volumes: loki-data, grafana-data                              │
└──────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Application** writes JSON logs to stdout
2. **Docker** captures logs from container stdout
3. **Promtail** discovers containers via Docker API
4. **Promtail** scrapes logs from `/var/lib/docker/containers`
5. **Promtail** adds labels (app, container, stream)
6. **Promtail** pushes logs to Loki via HTTP
7. **Loki** indexes logs by labels (not content!)
8. **Loki** stores log chunks in filesystem
9. **Grafana** queries Loki using LogQL
10. **Dashboard** displays logs and metrics

### Why This Architecture?

**Loki vs Elasticsearch:**
- **Lighter:** Indexes only labels, not full text
- **Cheaper:** Lower resource usage
- **Faster:** TSDB provides 10x query improvement
- **Simpler:** No complex schema management

**Docker Service Discovery:**
- **Automatic:** No manual configuration per container
- **Dynamic:** New containers automatically discovered
- **Filtered:** Only containers with `logging=promtail` label

---

## 2. Setup Guide

### 2.1 Prerequisites

- VM from Lab 04 (93.77.179.128)
- Docker and Docker Compose installed
- Ports open: 3000, 3100, 5000, 9080

### 2.2 Project Structure Created

```
monitoring/
├── docker-compose.yml          # Stack definition
├── loki/
│   └── config.yml             # Loki configuration
├── promtail/
│   └── config.yml             # Promtail configuration
├── .env                        # Environment variables (NOT in Git)
├── .gitignore                 # Excludes secrets
└── docs/
    └── LAB07.md              # This documentation
```

### 2.3 Deployment Steps

**Step 1: Build updated application image**
```bash
cd app_python
docker build --platform linux/amd64 -t prizrakzamkov/system-info-api:latest .
docker push prizrakzamkov/system-info-api:latest
```

**Step 2: Copy monitoring stack to VM**
```bash
scp -r monitoring ubuntu@93.77.179.128:/home/ubuntu/
```

**Step 3: Deploy stack**
```bash
ssh ubuntu@93.77.179.128
cd monitoring
docker compose up -d
```

**Step 4: Verify services**
```bash
docker compose ps
# All services should show "healthy" status

curl http://localhost:3100/ready
# Should return: ready

curl http://localhost:5000/health
# Should return JSON with status: healthy
```

**Step 5: Configure Grafana**
- Open http://93.77.179.128:3000
- Login: admin / secure-password-123
- Add Loki data source: http://loki:3100
- Create dashboard with 4 panels

### 2.4 Deployment Evidence

All services deployed successfully:
- ✅ Loki running and healthy (port 3100)
- ✅ Promtail running and scraping logs (port 9080)
- ✅ Grafana running with Loki data source (port 3000)
- ✅ System Info API running with JSON logging (port 5000)

**Screenshot** all services healthy

---

## 3. Configuration

### 3.1 Loki Configuration

**File:** `monitoring/loki/config.yml`

#### Key Sections Explained

**Server:**
```yaml
server:
  http_listen_port: 3100
```
- HTTP API port for receiving logs and queries

**Storage Schema (v13 with TSDB):**
```yaml
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb              # New in Loki 3.0
      object_store: filesystem
      schema: v13              # Latest schema version
      index:
        prefix: index_
        period: 24h
```

**Why TSDB?**
- **10x faster queries** compared to boltdb-shipper
- **Lower memory usage** during queries
- **Better compression** for index data
- **Required** for Loki 3.0+ in production

**Storage Backend:**
```yaml
storage_config:
  tsdb_shipper:
    active_index_directory: /loki/tsdb-index
    cache_location: /loki/tsdb-cache
  filesystem:
    directory: /loki/chunks
```
- Single-instance setup uses filesystem
- Production would use S3/GCS/Azure Blob

**Retention Policy:**
```yaml
limits_config:
  retention_period: 168h  # 7 days

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
  delete_request_store: filesystem  # Required for retention
```

**Why 7 days?**
- Balance between disk space and log availability
- Sufficient for debugging recent issues
- Configurable via variable in production

**Compactor:**
- Runs every 10 minutes
- Deletes logs older than retention period
- Compacts index files for efficiency

### 3.2 Promtail Configuration

**File:** `monitoring/promtail/config.yml`

#### Key Sections Explained

**Loki Client:**
```yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
```
- Where to send collected logs
- Uses Loki's push API endpoint

**Docker Service Discovery:**
```yaml
scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
        filters:
          - name: label
            values: ["logging=promtail"]
```

**How it works:**
1. Connects to Docker socket
2. Discovers containers every 5 seconds
3. Filters by label: `logging=promtail`
4. Automatically tracks new/removed containers

**Relabeling:**
```yaml
relabel_configs:
  - source_labels: ['__meta_docker_container_name']
    regex: '/(.*)'
    target_label: 'container'
  
  - source_labels: ['__meta_docker_container_label_app']
    target_label: 'app'
```

**Purpose:**
- Extracts container name (removes leading `/`)
- Creates `container` label from container name
- Creates `app` label from Docker label `app`
- Labels used for filtering in LogQL queries

**Why labels matter:**
- Loki indexes **only labels**, not log content
- Queries filter by labels first (fast)
- Then searches log content (slower)
- Good labels = fast queries

### 3.3 Docker Compose Configuration

**Key Features:**

**Networks:**
```yaml
networks:
  logging:
    name: logging
    driver: bridge
```
- Isolated network for logging stack
- All services communicate internally

**Volumes:**
```yaml
volumes:
  loki-data:      # Persistent log storage
  grafana-data:   # Dashboard and user data
```

**Health Checks:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 10s
```
- Verifies service is responding
- Used by `docker compose ps` to show status
- Allows graceful startup (start_period)

**Resource Limits:**
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

**Limits per service:**
- **Loki:** 1 CPU, 1GB RAM (handles queries and ingestion)
- **Grafana:** 1 CPU, 1GB RAM (renders dashboards)
- **Promtail:** 0.5 CPU, 512MB RAM (lightweight scraper)
- **Application:** 0.5 CPU, 512MB RAM (Flask app)

**Why limits?**
- Prevents resource exhaustion
- Ensures fair resource allocation
- Protects VM from OOM (out of memory) kills

---

## 4. Application Logging

### 4.1 JSON Logging Implementation

**File:** `app_python/app.py`

#### Custom JSON Formatter

```python
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # Add exception info if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        # Add extra fields from logger.info(..., extra={...})
        for key, value in record.__dict__.items():
            if key not in [standard_fields]:
                log_data[key] = value
        
        return json.dumps(log_data)
```

**What it does:**
- Converts Python log records to JSON format
- Includes standard fields (timestamp, level, message)
- Supports extra fields via `extra={}` parameter
- Adds exception stack traces when errors occur

#### Logging Configuration

```python
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logging.root.addHandler(handler)
logging.root.setLevel(logging.INFO)
```

**Key points:**
- Logs to **stdout** (Docker captures this)
- JSON format for structured data
- INFO level by default (can be changed via ENV)

### 4.2 Logged Events

**Application Startup:**
```python
logger.info('Application starting', extra={
    'hostname': socket.gethostname(),
    'platform': platform.system(),
    'python_version': platform.python_version()
})
```

**HTTP Requests (before_request):**
```python
logger.info('HTTP request received', extra={
    'method': request.method,
    'path': request.path,
    'remote_addr': request.remote_addr,
    'user_agent': request.headers.get('User-Agent')
})
```

**HTTP Responses (after_request):**
```python
logger.info('HTTP response sent', extra={
    'method': request.method,
    'path': request.path,
    'status_code': response.status_code,
    'content_length': response.content_length
})
```

**Errors (404):**
```python
logger.error('Page not found', extra={
    'path': request.path,
    'method': request.method,
    'remote_addr': request.remote_addr
})
```

**Exceptions:**
```python
logger.error('Unhandled exception', extra={
    'error': str(error),
    'path': request.path
}, exc_info=True)  # Includes stack trace
```

### 4.3 Example Log Output

```json
{
  "timestamp": "2026-03-11T18:30:45.123456+00:00",
  "level": "INFO",
  "logger": "__main__",
  "message": "HTTP request received",
  "module": "app",
  "function": "log_request",
  "line": 45,
  "method": "GET",
  "path": "/health",
  "remote_addr": "172.18.0.1",
  "user_agent": "curl/7.81.0"
}
```

### 4.4 Why JSON Logging?

**Benefits:**
- **Structured:** Fields are typed and parseable
- **Queryable:** Can filter by specific fields in LogQL
- **Machine-readable:** Easy for log aggregators
- **Context-rich:** Include any metadata needed

**Comparison:**

**Plain text:**
```
2026-03-11 18:30:45 INFO GET /health 200
```

**JSON:**
```json
{
  "timestamp": "2026-03-11T18:30:45Z",
  "level": "INFO",
  "method": "GET",
  "path": "/health",
  "status_code": 200,
  "duration_ms": 5.2,
  "user_id": "guest"
}
```

JSON allows queries like:
- `| json | status_code >= 400` (all errors)
- `| json | method="POST"` (only POST requests)
- `| json | duration_ms > 100` (slow requests)

---

## 5. Dashboard

### 5.1 Dashboard Overview

**Name:** Application Observability  
**Panels:** 4  
**Data Source:** Loki  
**Refresh:** Every 10 seconds (auto)


### 5.2 Panel 1: Application Logs

**Type:** Logs  
**Purpose:** View recent logs from all applications

**Query:**
```logql
{app=~"devops-.*"} | json
```

**Explanation:**
- `{app=~"devops-.*"}` - Label filter: match app starting with "devops-"
- `| json` - Parse JSON log lines into fields

**What it shows:**
- Last 100 log entries
- All log levels (INFO, ERROR)
- Parsed JSON fields visible in table

**Use cases:**
- Quick log inspection
- Debugging recent issues
- Verifying application behavior

### 5.3 Panel 2: Request Rate

**Type:** Time series (graph)  
**Purpose:** Monitor logging rate (proxy for request rate)

**Query:**
```logql
sum by (app) (rate({app=~"devops-.*"} [1m]))
```

**Explanation:**
- `rate({...} [1m])` - Calculate logs per second over 1-minute window
- `sum by (app)` - Group by application name
- Shows trend over time

**What it shows:**
- Logs per second for each application
- Spikes indicate increased traffic
- Useful for capacity planning

**Interpretation:**
- Flat line = steady traffic
- Spikes = bursts of requests
- Drop to zero = application stopped/crashed

### 5.4 Panel 3: Error Logs Only

**Type:** Logs  
**Purpose:** Show only ERROR level logs

**Query:**
```logql
{app=~"devops-.*"} | json | level="ERROR"
```

**Explanation:**
- `{app=~"devops-.*"}` - Select application logs
- `| json` - Parse JSON structure
- `| level="ERROR"` - Filter where level field equals ERROR

**What it shows:**
- Only ERROR level logs
- Exceptions and errors
- 404 responses
- Application failures

**Use cases:**
- Error monitoring
- Incident investigation
- Alert source (in production)

### 5.5 Panel 4: Log Level Distribution

**Type:** Pie chart  
**Purpose:** Visualize ratio of log levels

**Query:**
```logql
sum by (level) (count_over_time({app=~"devops-.*"} | json [5m]))
```

**Explanation:**
- `count_over_time({...} [5m])` - Count logs in last 5 minutes
- `| json` - Parse to access level field
- `sum by (level)` - Group counts by log level

**What it shows:**
- Percentage of INFO vs ERROR logs
- Visual health indicator
- Changes over time (if you adjust time range)

**Interpretation:**
- Mostly INFO = healthy application
- Increasing ERROR % = problems
- No logs = application down

### 5.6 LogQL Query Patterns

**Basic filtering:**
```logql
{app="devops-info-service"}                    # Exact match
{app=~"devops-.*"}                            # Regex match
{app="devops-info-service", level="ERROR"}    # Multiple labels
```

**Log parsing:**
```logql
{app="devops-info-service"} | json                     # Parse JSON
{app="devops-info-service"} | json | status_code=404   # Filter after parse
{app="devops-info-service"} | json | status_code >= 400 # Numeric comparison
```

**Aggregations:**
```logql
count_over_time({app="devops-info-service"} [5m])       # Count logs
rate({app="devops-info-service"} [1m])                  # Logs per second
sum by (level) (count_over_time({...} | json [5m]))     # Group by field
```

**Advanced:**
```logql
# Average response time (if you log it)
avg_over_time({app="devops-info-service"} | json | unwrap duration_ms [5m])

# Top 10 URLs by request count
topk(10, sum by (path) (count_over_time({app="devops-info-service"} | json [1h])))
```

---

## 6. Production Configuration

### 6.1 Security Measures

**Grafana Authentication:**
```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_USERS_ALLOW_SIGN_UP=false
```

**Implemented:**
- ✅ No anonymous access
- ✅ Admin password from environment variable
- ✅ New user registration disabled
- ✅ Password stored in `.env` file (not in Git)

**Network Security:**
- All services on isolated `logging` network
- Only necessary ports exposed to host
- Promtail has read-only access to Docker socket

**Secrets Management:**
```
.env file contains:
- GRAFANA_ADMIN_PASSWORD=secure-password-123

.gitignore excludes:
- .env
- Any other secrets
```

### 6.2 Resource Configuration

**Loki:**
- CPU: 0.5-1.0 cores
- Memory: 512MB-1GB
- Rationale: Handles ingestion + queries

**Promtail:**
- CPU: 0.25-0.5 cores
- Memory: 256MB-512MB
- Rationale: Lightweight log scraper

**Grafana:**
- CPU: 0.5-1.0 cores
- Memory: 512MB-1GB
- Rationale: Dashboard rendering

**Application:**
- CPU: 0.25-0.5 cores
- Memory: 256MB-512MB
- Rationale: Flask app with low traffic

**Total VM Requirements:**
- Minimum: 2 vCPU, 2GB RAM
- Recommended: 4 vCPU, 4GB RAM
- Current: 2 vCPU @ 20%, 2GB RAM (Yandex Cloud free tier)

### 6.3 Retention Policy

**Configuration:**
```yaml
limits_config:
  retention_period: 168h  # 7 days

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
  compaction_interval: 10m
```

**How it works:**
1. Logs older than 7 days marked for deletion
2. Compactor runs every 10 minutes
3. After 2-hour delay, logs permanently deleted
4. Index files compacted for efficiency

**Disk usage estimation:**
```
Application logs: ~100 MB/day
Loki logs: ~10 MB/day
Promtail logs: ~5 MB/day
Grafana logs: ~5 MB/day

Total per day: ~120 MB
7-day retention: ~850 MB
With overhead: ~1 GB
```

**Adjusting retention:**
To change retention period, modify `loki/config.yml`:
```yaml
limits_config:
  retention_period: 720h  # 30 days
```

Then restart: `docker compose restart loki`

### 6.4 Health Checks

**Loki:**
```bash
curl http://localhost:3100/ready
# Returns: ready (if healthy)
```

**Grafana:**
```bash
curl http://localhost:3000/api/health
# Returns: {"database":"ok","version":"12.3.1"}
```

**Promtail:**
```bash
curl http://localhost:9080/targets
# Returns JSON list of discovered containers
```

**Application:**
```bash
curl http://localhost:5000/health
# Returns: {"status":"healthy",...}
```

**Automated checks:**
Docker Compose health checks run every 10 seconds:
```bash
docker compose ps
# Shows health status for all services
```

---

## 7. Testing

### 7.1 Connectivity Tests

**Loki availability:**
```bash
curl http://93.77.179.128:3100/ready
# Expected: ready
```

**Promtail targets:**
```bash
curl http://93.77.179.128:9080/targets | jq
# Expected: JSON with discovered containers
```

**Grafana health:**
```bash
curl http://93.77.179.128:3000/api/health
# Expected: {"database":"ok",...}
```

**Application health:**
```bash
curl http://93.77.179.128:5000/health
# Expected: {"status":"healthy",...}
```

### 7.2 Log Generation Tests

**Generate INFO logs:**
```bash
for i in {1..20}; do
  curl http://93.77.179.128:5000/
done
```

**Generate ERROR logs:**
```bash
for i in {1..5}; do
  curl http://93.77.179.128:5000/nonexistent-page
done
```

**Verify in Grafana:**
1. Open Explore
2. Query: `{app="devops-info-service"} | json`
3. Should see new logs appear within 5-10 seconds

### 7.3 Dashboard Tests

**Panel 1 - Application Logs:**
- Should show recent logs
- JSON fields should be parsed
- Click on log line → see full JSON

**Panel 2 - Request Rate:**
- Graph should show activity
- Spikes correspond to curl commands
- Legend shows app name

**Panel 3 - Error Logs:**
- Should show 404 errors
- Only ERROR level visible
- Matches number of /nonexistent-page requests

**Panel 4 - Log Level Distribution:**
- Pie chart shows INFO vs ERROR ratio
- Percentages add up to 100%
- Updates when time range changes

### 7.4 Performance Tests

**Query speed test:**
```logql
{app="devops-info-service"} | json
```
- Should return results in < 1 second
- TSDB provides fast queries even with large datasets

**Ingestion test:**
```bash
# Generate 1000 requests
for i in {1..1000}; do
  curl -s http://93.77.179.128:5000/ > /dev/null
done

# Check Promtail caught up
docker logs promtail | grep "sent batch"
```

**Resource usage:**
```bash
docker stats --no-stream
# Monitor CPU and memory usage during load
```

---

## 8. Challenges and Solutions

### Challenge 1: Loki Configuration Error

**Problem:**
```
level=error msg="validating config" err="CONFIG ERROR: invalid compactor config: 
compactor.delete-request-store should be configured when retention is enabled"
```

**Root Cause:**
Loki 3.0 requires `delete_request_store` to be explicitly configured when retention is enabled.

**Solution:**
Added to `compactor` section in `loki/config.yml`:
```yaml
compactor:
  delete_request_store: filesystem
```

**Lesson Learned:**
Always check Loki documentation for version-specific requirements. Loki 3.0 has stricter validation than 2.x.

### Challenge 2: Platform-Specific Docker Build

**Problem:**
```
exec /bin/sh: exec format error
```

**Root Cause:**
Building Docker image on WSL2/Windows creates ARM architecture image by default, but VM is x86_64.

**Solution:**
Added `--platform linux/amd64` flag:
```bash
docker build --platform linux/amd64 -t prizrakzamkov/system-info-api:latest .
```

**Alternative:**
Build directly on VM:
```bash
scp -r app_python ubuntu@93.77.179.128:/home/ubuntu/
ssh ubuntu@93.77.179.128
cd app_python
docker build -t prizrakzamkov/system-info-api:latest .
```

**Lesson Learned:**
Always specify target platform when building on different architecture.

### Challenge 3: Container Name Conflict

**Problem:**
```
Error: The container name "/system-info-api" is already in use
```

**Root Cause:**
Old container from previous labs still running.

**Solution:**
```bash
docker stop system-info-api
docker rm system-info-api
docker compose up -d
```

**Prevention:**
Always use `docker compose down` before redeploying to clean up old containers.

### Challenge 4: WSL2 I/O Errors

**Problem:**
```
-bash: /usr/bin/sudo: Input/output error
```

**Root Cause:**
WSL2 corruption or filesystem issues.

**Solution:**
```powershell
# Restart WSL2
wsl --shutdown
# Wait 10 seconds
wsl -d Ubuntu-24.04
```

**Prevention:**
Work in Linux filesystem (`~/projects/`) instead of Windows mounts (`/mnt/d/`).

### Challenge 5: No Logs in Grafana

**Problem:**
Grafana Explore shows no logs despite application running.

**Debugging Steps:**
1. Check Promtail targets: `curl http://localhost:9080/targets`
2. Verify container has label: `docker inspect system-info-api | grep logging`
3. Check Promtail logs: `docker logs promtail`
4. Generate test logs: `curl http://localhost:5000/`
5. Wait 10 seconds for ingestion pipeline

**Solution:**
Ensure container has correct label in docker-compose.yml:
```yaml
labels:
  logging: "promtail"
  app: "devops-info-service"
```

---

## Summary

### Accomplishments

**Technical Implementation:**
- ✅ Deployed Loki 3.0 with TSDB storage
- ✅ Configured Promtail with Docker service discovery
- ✅ Set up Grafana 12.3 with Loki data source
- ✅ Implemented JSON logging in Python application
- ✅ Created 4-panel observability dashboard
- ✅ Configured 7-day log retention
- ✅ Added resource limits and health checks
- ✅ Secured Grafana with authentication

**Skills Gained:**
- LogQL query language basics
- Docker Compose orchestration
- Structured logging implementation
- Grafana dashboard creation
- Log aggregation architecture
- Production logging best practices

### Key Learnings

**Architecture:**
- Loki is not Elasticsearch - it indexes labels, not content
- Labels are crucial for query performance
- TSDB provides significant performance improvements

**Operations:**
- Health checks are essential for monitoring
- Resource limits prevent OOM kills
- Retention policies manage disk usage
- JSON logging enables powerful filtering

**Development:**
- Structured logging from day one
- Context-rich logs aid debugging
- Log levels communicate severity
- Extra fields provide valuable metadata

### Time Investment

- Setup and configuration: 2 hours
- Application modification: 1 hour
- Dashboard creation: 1.5 hours
- Testing and debugging: 1 hour
- Documentation: 1.5 hours

**Total: ~7 hours**

### Production Readiness

This setup is **suitable for development/staging** with minor adjustments needed for production:

**Current State:**
- ✅ Authentication enabled
- ✅ Resource limits configured
- ✅ Health checks implemented
- ✅ Retention policy active

**Production TODO:**
- [ ] Use external object storage (S3/GCS) instead of filesystem
- [ ] Implement multi-tenant setup if needed
- [ ] Add alerting based on log patterns
- [ ] Configure backup for Grafana dashboards
- [ ] Use secrets management (Vault/AWS Secrets Manager)
- [ ] Implement log sampling for high-volume apps
- [ ] Add SSL/TLS for all HTTP endpoints

---

## Appendix

### A. Configuration Files

**Loki config.yml** - See `monitoring/loki/config.yml`
**Promtail config.yml** - See `monitoring/promtail/config.yml`
**Docker Compose** - See `monitoring/docker-compose.yml`

### B. LogQL Cheat Sheet

```logql
# Label filtering
{app="myapp"}                       # Exact match
{app=~"myapp|otherapp"}            # Regex OR
{app!="exclude"}                   # Not equal
{app=~"dev.*"}                     # Regex pattern

# Log parsing
| json                              # Parse JSON
| logfmt                            # Parse logfmt
| regexp "(?P<level>\\w+)"         # Custom regex

# Line filtering
|= "error"                         # Contains
!= "debug"                         # Not contains
|~ "error|warn"                    # Regex match
!~ "debug|trace"                   # Regex not match

# Field filtering (after parsing)
| level="ERROR"                    # Exact match
| status_code >= 400               # Numeric
| duration_ms > 100                # Threshold

# Aggregations
count_over_time({app="myapp"} [5m])
rate({app="myapp"} [1m])
sum by (level) (count_over_time(...))
avg_over_time(...| unwrap field [5m])
```

### C. Useful Commands

```bash
# Check all logs
docker compose logs

# Follow specific service
docker compose logs -f loki

# Restart single service
docker compose restart promtail

# View Promtail discovered targets
curl http://localhost:9080/targets | jq

# Query Loki directly
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={app="devops-info-service"}' | jq

# Generate test logs
while true; do curl http://localhost:5000/; sleep 1; done

# Check disk usage
docker system df
docker volume ls
```

### D. Screenshots Location

All screenshots for this lab are in:
```    
app_python -> docs -> lab7screens
```

---

**Lab Completed:** March 11, 2026  
**Status:** ✅ All tasks completed successfully  

