# System Information API Service

A lightweight Flask-based REST API that delivers system metrics, Python environment data, and request information through JSON endpoints. Built as part of DevOps Engineering Lab 01.

## What It Does

This microservice exposes HTTP endpoints that return structured data about the underlying operating system, Python interpreter configuration, and HTTP request context.

## Requirements

- Python 3.11 or higher
- pip package manager

## Setup Instructions

```bash
cd app_python
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Starting the Service

```bash
python app.py
```

The API will be available at `http://0.0.0.0:6000`

## Available Endpoints

### `GET /`

Delivers a comprehensive JSON response containing service metadata, operating system details, Python runtime configuration, HTTP request information, and a list of accessible endpoints.

```bash
curl http://localhost:5000/
```

### `GET /health`

Provides service health information including current timestamp and uptime metrics.

```bash
curl http://localhost:5000/health
```

## Environment Configuration

Customize the application behavior using these environment variables:

| Variable | Purpose | Default Value |
|----------|---------|---------------|
| `HOST` | Network interface to bind | `0.0.0.0` |
| `PORT` | TCP port to listen on | `5000` |
| `DEBUG` | Toggle debug mode | `false` |

Usage example:

```bash
HOST=127.0.0.1 PORT=8080 DEBUG=true python app.py
```