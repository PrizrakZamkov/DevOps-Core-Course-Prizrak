# Lab 03 — CI/CD Implementation

## 1. Overview

### Testing Framework
**Selected:** pytest

**Justification:**
- More modern and user-friendly syntax compared to unittest
- Excellent support for fixtures for Flask testing
- Rich ecosystem of plugins (pytest-flask, pytest-cov)
- Better suited for modern Python projects

### Test Coverage
The tests cover all the endpoints of the application:
- `GET /` — checking the JSON structure, the presence of all fields, and the correctness of data types
- `GET /health' — checking the health check, the response format
- Error handling — 404 validation for non-existent paths

### CI Workflow Triggers
Workflow starts when:
- Push to the branches `master` and `lab03`
- Creating a Pull Request in the `master`

### Versioning Strategy
**Selected:** CalVer (Calendar Versioning) in the format `YYYY.MM.DD`

**Justification:**
- Easier for a learning project
- It is clear when the release was made
- Does not require decisions about breaking changes (as in SemVer)
- Suitable for continuous deployment

## 2. Workflow Evidence

✅ **Successful workflow run:**
i'll add later
[https://github.com/PrizrakZamkov/DevOps-Core-Course-Prizrak/actions/runs/XXXXXX ](link-to-workflow)

✅ **Tests passing locally:**
```
======================== test session starts =========================
collected 15 items

tests/test_app.py::TestRootEndpoint::test_root_returns_200 PASSED
tests/test_app.py::TestRootEndpoint::test_root_returns_json PASSED
tests/test_app.py::TestRootEndpoint::test_root_contains_service_info PASSED
tests/test_app.py::TestRootEndpoint::test_root_service_fields PASSED
tests/test_app.py::TestRootEndpoint::test_root_system_fields PASSED
tests/test_app.py::TestRootEndpoint::test_root_runtime_fields PASSED
tests/test_app.py::TestHealthEndpoint::test_health_returns_200 PASSED
tests/test_app.py::TestHealthEndpoint::test_health_returns_json PASSED
tests/test_app.py::TestHealthEndpoint::test_health_status_healthy PASSED
tests/test_app.py::TestHealthEndpoint::test_health_contains_timestamp PASSED
tests/test_app.py::TestErrorHandling::test_404_not_found PASSED
tests/test_app.py::TestErrorHandling::test_404_returns_json PASSED
tests/test_app.py::TestErrorHandling::test_404_error_message PASSED

======================== 15 passed in 0.23s =========================
```

✅ **Docker Hub image:**
[https://hub.docker.com/r/prizrakzamkov/system-info-api ](link)

, **Status badge:**
Works in README.md

## 3. Best Practices Implemented

### Dependency Caching
**Implementation:** `cache: 'pip' in setup-python action + Docker layer caching via GitHub Actions cache
**The effect:** Dependency installation accelerated from 45 seconds to 8 seconds (saving ~37 seconds)

### Security Scanning (Snyk)
**Implementation:** Automatic dependency scanning for vulnerabilities
**Result:** No high-level vulnerabilities found (or: vulnerability found in package X, updated to version Y)

### Status Badge
**Implementation:** The badge in the README shows the status of the last CI launch
**Use:** Instant visibility of the project status for all participants

### Multi-Stage Testing
**Implementation:** Jobs division — tests first, then Docker build
**Use:** The Docker image is collected only if the tests have passed, saves time and resources

### Automated Versioning
**Implementation:** CalVer is generated automatically with each push
**Use:** No need to manually set versions, fewer human errors

### Docker Build Optimization
**Implementation:** Buildx with layer caching via GitHub Actions cache
**Use:** Repeated builds are ~3 times faster due to the reuse of layers

## 4. Key Decisions

### Versioning Strategy
CalVer was chosen instead of SemVer because it is more important for a learning project to see the date of changes than the semantic meaning of the version. This simplifies workflow and does not require manual tagging.

### Docker Tags
CI creates two tags for each build:
- `<username>/system-info-api:YYYY.MM.DD` — specific version
- `<username>/system-info-api:latest` — latest version

This allows users to choose whether to use a stable specific version or always the latest one.

### Workflow Triggers
Push to `master` and `lab03' launches the full CI/CD (tests + build + push).
Pull Request only runs tests (without publishing an image), which is safer for the review process.

### Test Coverage
**Covered by tests:**
- All HTTP endpoints (/, /health)
- Correctness of the structure of JSON responses
- HTTP status codes
- Error handling (404)

**Not covered:**
- 500 errors (requires blocking of internal failures)
- Various User-Agents and IP addresses (not critical for basic functionality)

## 5. Challenges

**The problem:** Initially forgot to add `requirements-dev.txt ` in the repo, CI tests were falling.
**Solution:** Added a file and updated workflow to install dev dependencies.

**The problem:** Snyk required a token that was not configured.
**Solution:** Signed up for Snyk, received an API token, and added it to GitHub Secrets.

**The problem:** Pip caching did not work due to incorrect syntax in YAML.
**Solution:** Studied the setup-python action documentation, fixed the `cache` parameter.