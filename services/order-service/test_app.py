from app import app

def test_health_endpoint():
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"

def test_index_endpoint():
    response = app.test_client().get("/")
    assert response.status_code == 200
