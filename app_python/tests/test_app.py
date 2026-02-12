import pytest
from app import app


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


class TestRootEndpoint:
    def test_root_returns_200(self, client):
        """Test that root endpoint returns 200 code"""
        response = client.get('/')
        assert response.status_code == 200
    
    def test_root_returns_json(self, client):
        """Test that root endpoint returns JSON"""
        response = client.get('/')
        assert response.content_type == 'application/json'
    
    def test_root_contains_service_info(self, client):
        """Test that root endpoint contains service information"""
        response = client.get('/')
        data = response.get_json()
        
        assert 'service' in data
        assert 'system' in data
        assert 'runtime' in data
        assert 'request' in data
        assert 'endpoints' in data
    
    def test_root_service_fields(self, client):
        """service section has required fields"""
        response = client.get('/')
        data = response.get_json()
        service = data['service']
        
        assert service['name'] == 'System Information API'
        assert service['version'] == '1.0.0'
        assert 'description' in service
        assert service['framework'] == 'Flask'
    
    def test_root_system_fields(self, client):
        """system section has required fields"""
        response = client.get('/')
        data = response.get_json()
        system = data['system']
        
        assert 'hostname' in system
        assert 'platform' in system
        assert 'architecture' in system
        assert 'cpu_count' in system
        assert isinstance(system['cpu_count'], int)
    
    def test_root_runtime_fields(self, client):
        """runtime section has fields"""
        response = client.get('/')
        data = response.get_json()
        runtime = data['runtime']
        
        assert 'python_version' in runtime
        assert 'uptime_seconds' in runtime
        assert 'uptime_human' in runtime
        assert 'current_time' in runtime
        assert runtime['timezone'] == 'UTC'


class TestHealthEndpoint:
    """health check endpoint (/health)"""
    
    def test_health_returns_200(self, client):
        """Test that health endpoint returns 200 code"""
        response = client.get('/health')
        assert response.status_code == 200
    
    def test_health_returns_json(self, client):
        """health endpoint returns json"""
        response = client.get('/health')
        assert response.content_type == 'application/json'
    
    def test_health_status_healthy(self, client):
        """health endpoint returns healthy status"""
        response = client.get('/health')
        data = response.get_json()
        
        assert data['status'] == 'healthy'
    
    def test_health_contains_timestamp(self, client):
        """health endpoint contains timestamp"""
        response = client.get('/health')
        data = response.get_json()
        
        assert 'timestamp' in data
        assert 'uptime_seconds' in data
        assert isinstance(data['uptime_seconds'], (int, float))


class TestErrorHandling:
    """error handling"""
    
    def test_404_not_found(self, client):
        """Test that non-existent returns 404 error"""
        response = client.get('/nonexistent')
        assert response.status_code == 404
    
    def test_404_returns_json(self, client):
        """Test that 404 error returns json"""
        response = client.get('/nonexistent')
        assert response.content_type == 'application/json'
    
    def test_404_error_message(self, client):
        """Test that 404 error contains information"""
        response = client.get('/nonexistent')
        data = response.get_json()
        
        assert 'error' in data
        assert data['error'] == 'Not Found'
        assert 'path' in data
