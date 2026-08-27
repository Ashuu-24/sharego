from __future__ import annotations

from sqlmodel import Session

from app.db import engine
from app.models import User
from app.core.security import hash_password


def test_admin_cookie_login_browser_flow(reset_db, client):
    with Session(engine) as session:
        admin = User(
            email="admin-cookie@example.com",
            phone="",
            password_hash=hash_password("Admin1234"),
            roles_csv="admin,user",
            kyc_status="approved",
        )
        session.add(admin)
        session.commit()

    first = client.get("/admin", headers={"accept": "text/html"}, follow_redirects=False)
    assert first.status_code == 303
    assert first.headers["location"].startswith("/admin/login?")

    login = client.post(
        "/admin/login",
        data={
            "email": "admin-cookie@example.com",
            "password": "Admin1234",
            "next": "/admin",
        },
        follow_redirects=False,
    )
    assert login.status_code == 303
    assert login.headers["location"] == "/admin"
    assert "Flyro_admin_access=" in login.headers.get("set-cookie", "")

    panel = client.get("/admin", headers={"accept": "text/html"})
    assert panel.status_code == 200
    assert "text/html" in panel.headers.get("content-type", "")
    assert "Dashboard" in panel.text

    logout = client.post("/admin/logout", follow_redirects=False)
    assert logout.status_code == 303
    assert logout.headers["location"] == "/admin/login"

    after = client.get("/admin", headers={"accept": "text/html"}, follow_redirects=False)
    assert after.status_code == 303
    assert after.headers["location"].startswith("/admin/login?")


def test_admin_cookie_login_rejects_invalid_credentials(reset_db, client):
    with Session(engine) as session:
        admin = User(
            email="admin-invalid@example.com",
            phone="",
            password_hash=hash_password("Admin1234"),
            roles_csv="admin",
            kyc_status="approved",
        )
        session.add(admin)
        session.commit()

    bad = client.post(
        "/admin/login",
        data={
            "email": "admin-invalid@example.com",
            "password": "wrong-password",
            "next": "/admin",
        },
    )
    assert bad.status_code == 401
    assert "Invalid email or password" in bad.text

