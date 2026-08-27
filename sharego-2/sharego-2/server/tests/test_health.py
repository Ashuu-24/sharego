from fastapi.testclient import TestClient

from app.main import app


def test_health_returns_ok_and_settings():
    client = TestClient(app)
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "env" in data
    assert "timezone" in data
    assert "currency" in data
