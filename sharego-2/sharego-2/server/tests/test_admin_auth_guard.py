from fastapi.testclient import TestClient
from sqlmodel import SQLModel, Session

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db import engine
from app.main import app
from app.models import User


def _reset_db() -> None:
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)


def _auth(email: str, roles: list[str]) -> dict[str, str]:
    token = create_access_token(
        subject=email,
        settings=get_settings(),
        extra_claims={"roles": roles},
    )
    return {"Authorization": f"Bearer {token}"}


def test_admin_routes_require_auth_and_admin_role() -> None:
    _reset_db()
    with Session(engine) as session:
        session.add(User(email="admin-guard-admin@example.com", phone="", roles_csv="admin", kyc_status="approved"))
        session.add(User(email="admin-guard-user@example.com", phone="", roles_csv="user", kyc_status="approved"))
        session.commit()

    client = TestClient(app)

    no_auth = client.get("/admin")
    assert no_auth.status_code == 401
    assert no_auth.json()["error"]["code"] == "http_401"

    non_admin = client.get(
        "/admin",
        headers=_auth("admin-guard-user@example.com", ["user"]),
    )
    assert non_admin.status_code == 403
    assert non_admin.json()["error"]["code"] == "http_403"

    admin = client.get(
        "/admin",
        headers=_auth("admin-guard-admin@example.com", ["admin"]),
    )
    assert admin.status_code == 200
    assert "text/html" in admin.headers.get("content-type", "")
