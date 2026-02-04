"""System Information API - Flask-based web service for Lab 01."""

import time
import logging
import os
import platform
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, request

app = Flask(__name__)

STARTUP_TIMESTAMP = time.time()

BIND_HOST = os.environ.get("HOST", "0.0.0.0")
BIND_PORT = int(os.environ.get("PORT", 6000))
DEBUG_MODE = os.environ.get("DEBUG", "false").lower() == "true"

logging.basicConfig(
    level=logging.DEBUG if DEBUG_MODE else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger(__name__)


@app.route("/")
def root_endpoint():
    """Provide complete service information and system metrics."""
    log.info("Root endpoint accessed from %s", request.remote_addr)

    elapsed_time = time.time() - STARTUP_TIMESTAMP
    timestamp_now = datetime.now(timezone.utc).isoformat()

    data = {
        "service": {
            "name": "System Information API",
            "version": "1.0.0",
            "description": "REST API delivering system and runtime metrics",
            "framework": "Flask",
        },
        "system": {
            "hostname": socket.gethostname(),
            "platform": platform.system(),
            "platform_version": platform.version(),
            "architecture": platform.machine(),
            "cpu_count": os.cpu_count(),
        },
        "runtime": {
            "python_version": platform.python_version(),
            "uptime_seconds": round(elapsed_time, 2),
            "uptime_human": f"{int(elapsed_time // 3600)} hours, {int((elapsed_time % 3600) // 60)} minutes",
            "current_time": timestamp_now,
            "timezone": "UTC",
        },
        "request": {
            "client_ip": request.remote_addr,
            "user_agent": request.headers.get("User-Agent", ""),
            "method": request.method,
            "path": request.path,
        },
        "endpoints": [
            {"path": "/", "method": "GET", "description": "Complete service information"},
            {"path": "/health", "method": "GET", "description": "Service health status"},
        ],
    }

    return jsonify(data)


@app.route("/health")
def health_check():
    """Provide service health and availability status."""
    log.info("Health check endpoint accessed from %s", request.remote_addr)

    elapsed_time = time.time() - STARTUP_TIMESTAMP
    timestamp_now = datetime.now(timezone.utc).isoformat()

    return jsonify({
        "status": "healthy",
        "timestamp": timestamp_now,
        "uptime_seconds": round(elapsed_time, 2),
    }), 200


@app.errorhandler(404)
def handle_not_found(error):
    """Process 404 Not Found errors."""
    log.warning("Resource not found: %s %s", request.method, request.path)
    return jsonify({"error": "Not Found", "path": request.path}), 404


@app.errorhandler(500)
def handle_server_error(error):
    """Process 500 Internal Server errors."""
    log.error("Internal server error occurred: %s", error)
    return jsonify({"error": "Internal Server Error"}), 500


if __name__ == "__main__":
    log.info("Launching System Information API on %s:%d (debug=%s)", BIND_HOST, BIND_PORT, DEBUG_MODE)
    app.run(host=BIND_HOST, port=BIND_PORT, debug=DEBUG_MODE)