from __future__ import annotations

import pytest

from app.core.config import get_settings
from app.main import create_application
from tests.conftest import auth_headers, create_user


def test_user_lookup_requires_auth_and_hides_pii(reset_db, client):
    actor = create_user("actor@example.com")
    target = create_user("target@example.com")

    unauthorized = client.get(f"/users/{target.id}")
    assert unauthorized.status_code == 401

    ok = client.get(f"/users/{target.id}", headers=auth_headers(actor.email))
    assert ok.status_code == 200
    body = ok.json()
    assert body["id"] == target.id
    assert "email" not in body
    assert "phone" not in body
    assert "roles" not in body


def test_health_adds_security_headers(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.headers.get("x-content-type-options") == "nosniff"
    assert resp.headers.get("x-frame-options") == "DENY"
    assert resp.headers.get("referrer-policy") == "no-referrer"
    assert resp.headers.get("permissions-policy") == "camera=(), microphone=(), geolocation=()"


def test_prod_rejects_weak_jwt_secret(monkeypatch):
    monkeypatch.setenv("ENV", "prod")
    monkeypatch.setenv("JWT_SECRET", "change_me")
    get_settings.cache_clear()
    with pytest.raises(RuntimeError, match="JWT_SECRET"):
        create_application()
    get_settings.cache_clear()
