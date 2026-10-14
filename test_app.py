import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health(client):
    rv = client.get('/health')
    assert rv.status_code == 200
    data = rv.get_json()
    assert data['status'] == 'healthy'

def test_home_page(client):
    rv = client.get('/')
    assert rv.status_code == 200
    assert b'Raham Restaurant' in rv.data
