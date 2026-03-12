import json
import logging
import sys
from datetime import datetime, timezone
from flask import Flask, request, jsonify
import socket
import platform

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

logger.info('Application starting', extra={
    'hostname': socket.gethostname(),
    'platform': platform.system(),
    'python_version': platform.python_version()
})

@app.before_request
def log_request():
    logger.info('HTTP request received', extra={
        'method': request.method,
        'path': request.path,
        'remote_addr': request.remote_addr,
        'user_agent': request.headers.get('User-Agent', 'Unknown')
    })

@app.after_request
def log_response(response):
    logger.info('HTTP response sent', extra={
        'method': request.method,
        'path': request.path,
        'status_code': response.status_code,
        'content_length': response.content_length
    })
    return response

@app.route('/')
def index():
    return jsonify({
        'service': 'System Information API',
        'version': '2.0.0',
        'hostname': socket.gethostname(),
        'platform': platform.system()
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now(timezone.utc).isoformat()
    })

@app.errorhandler(404)
def not_found(error):
    logger.error('Page not found', extra={
        'path': request.path,
        'method': request.method,
        'remote_addr': request.remote_addr
    })
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(Exception)
def handle_exception(error):
    logger.error('Unhandled exception', extra={
        'error': str(error),
        'path': request.path,
        'method': request.method
    }, exc_info=True)
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    logger.info('Starting Flask server')
    app.run(host='0.0.0.0', port=6000, debug=False)