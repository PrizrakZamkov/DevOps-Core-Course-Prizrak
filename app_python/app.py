import json
import logging
import sys
import time
from datetime import datetime, timezone
from flask import Flask, request, jsonify
import socket
import platform
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import os
from pathlib import Path

# JSON Formatter for structured logging
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
        
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        for key, value in record.__dict__.items():
            if key not in ['name', 'msg', 'args', 'created', 'filename', 'funcName', 
                          'levelname', 'levelno', 'lineno', 'module', 'msecs', 
                          'message', 'pathname', 'process', 'processName', 
                          'relativeCreated', 'thread', 'threadName', 'exc_info', 
                          'exc_text', 'stack_info']:
                log_data[key] = value
        
        return json.dumps(log_data)

# Setup logging
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logging.root.addHandler(handler)
logging.root.setLevel(logging.INFO)

logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus Metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

http_requests_in_progress = Gauge(
    'http_requests_in_progress',
    'HTTP requests currently being processed'
)

endpoint_calls = Counter(
    'devops_info_endpoint_calls',
    'Endpoint-specific call counter',
    ['endpoint']
)

logger.info('Application starting', extra={
    'hostname': socket.gethostname(),
    'platform': platform.system(),
    'python_version': platform.python_version()
})

# Visits counter
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
        # Create directory if doesn't exist
        VISITS_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        count = get_visits() + 1
        VISITS_FILE.write_text(str(count))
        return count
    except Exception as e:
        logger.error(f'Error writing visits: {e}')
        return get_visits()

@app.before_request
def before_request():
    request.start_time = time.time()
    http_requests_in_progress.inc()
    
    logger.info('HTTP request received', extra={
        'method': request.method,
        'path': request.path,
        'remote_addr': request.remote_addr,
        'user_agent': request.headers.get('User-Agent', 'Unknown')
    })

@app.after_request
def after_request(response):
    # Calculate request duration
    request_duration = time.time() - request.start_time
    
    # Normalize endpoint for metrics
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
    
    logger.info('HTTP response sent', extra={
        'method': request.method,
        'path': request.path,
        'status_code': response.status_code,
        'content_length': response.content_length,
        'duration_seconds': round(request_duration, 4)
    })
    
    return response

@app.route('/')
def index():
    endpoint_calls.labels(endpoint='index').inc()
    
    # Increment visits
    visits = increment_visits()
    
    return jsonify({
        'service': 'System Information API',
        'version': '2.0.0',
        'hostname': socket.gethostname(),
        'platform': platform.system(),
        'metrics_available': '/metrics',
        'visits': visits
    })

@app.route('/health')
def health():
    endpoint_calls.labels(endpoint='health').inc()
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now(timezone.utc).isoformat()
    })

@app.route('/visits')
def visits():
    """Return current visits count"""
    count = get_visits()
    return jsonify({
        'visits': count
    })

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.errorhandler(404)
def not_found(error):
    logger.error('Page not found', extra={
        'path': request.path,
        'method': request.method,
        'remote_addr': request.remote_addr
    })
    
    http_requests_total.labels(
        method=request.method,
        endpoint='not_found',
        status=404
    ).inc()
    
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(Exception)
def handle_exception(error):
    logger.error('Unhandled exception', extra={
        'error': str(error),
        'path': request.path,
        'method': request.method
    }, exc_info=True)
    
    http_requests_total.labels(
        method=request.method,
        endpoint='error',
        status=500
    ).inc()
    
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    logger.info('Starting Flask server')
    app.run(
        host=os.getenv('HOST', '0.0.0.0'),
        port=int(os.getenv('PORT', '6000')),
        debug=os.getenv('DEBUG', 'false').lower() == 'true'
    )
