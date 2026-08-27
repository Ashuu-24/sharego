from fastapi.testclient import TestClient
from jose import jwt

from sqlmodel import Session, SQLModel, select
from sqlalchemy import delete

from app.core.limits import limiter
from app.main import app
from app.core.config import get_settings
from app.models import OTPEntry, OTPThrottle, User
from app.db import engine


def reset_db():
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        session.exec(delete(OTPThrottle))
        session.exec(delete(OTPEntry))
        session.exec(delete(User))
        session.commit()
    limiter._storage.reset()


def test_register_returns_dev_otp():
    reset_db()
    client = TestClient(app)
    resp = client.post("/auth/register", json={"email": "user@example.com"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["otp_dev"] == "123456"


def test_verify_otp_success_and_failure():
    reset_db()
    client = TestClient(app)
    client.post("/auth/register", json={"email": "user@example.com"})
    ok = client.post("/auth/verify-otp", json={"email": "user@example.com", "otp": "123456"})
    assert ok.status_code == 200
    data = ok.json()
    assert data["roles"] == ["user"]
    token = data["access_token"]
    claims = jwt.decode(token, get_settings().jwt_secret, algorithms=[get_settings().jwt_alg])
    assert claims["sub"] == "user@example.com"
    assert claims["roles"] == ["user"]

    bad = client.post("/auth/verify-otp", json={"email": "user@example.com", "otp": "000000"})
    assert bad.status_code == 400


def test_users_me_requires_auth_and_returns_profile():
    reset_db()
    client = TestClient(app)

    unauthorized = client.get("/users/me")
    assert unauthorized.status_code == 401

    client.post("/auth/register", json={"email": "me@example.com"})
    login = client.post("/auth/verify-otp", json={"email": "me@example.com", "otp": "123456"})
    assert login.status_code == 200
    token = login.json()["access_token"]

    ok = client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert ok.status_code == 200
    body = ok.json()
    assert body["email"] == "me@example.com"
