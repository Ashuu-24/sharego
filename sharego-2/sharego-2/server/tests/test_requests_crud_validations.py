from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db import engine
from app.main import app
from app.models import User


def reset_db() -> None:
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)


def create_user(email: str, *, rating_avg: float = 0.0, kyc_status: str = "approved") -> User:
    with Session(engine) as session:
        user = User(email=email, phone="", roles_csv="user", rating_avg=rating_avg, kyc_status=kyc_status)
        session.add(user)
        session.commit()
        session.refresh(user)
        return user


def auth_headers(email: str) -> dict[str, str]:
    token = create_access_token(
        subject=email,
        settings=get_settings(),
        extra_claims={"roles": ["user"]},
    )
    return {"Authorization": f"Bearer {token}"}


def _payload(**overrides) -> dict:
    base = {
        "product_name": "Apple MacBook Pro",
        "specs_json": '{"color":"space gray"}',
        "target_price": 150000,
        "dest_city": "Lahore",
        "weight_kg": 2.4,
        "window_start": "2026-01-10T10:00:00",
        "window_end": "2026-01-20T10:00:00",
        "declaration_path": "docs/macbook.pdf",
    }
    base.update(overrides)
    return base


def test_requests_crud_validations_and_ownership() -> None:
    reset_db()
    owner = create_user("owner@example.com")
    other = create_user("other@example.com")
    owner_headers = auth_headers(owner.email)
    other_headers = auth_headers(other.email)

    client = TestClient(app)

    unauthorized = client.post("/requests", json=_payload())
    assert unauthorized.status_code == 401

    invalid_window = client.post(
        "/requests",
        json=_payload(window_start="2026-01-20T10:00:00", window_end="2026-01-10T10:00:00"),
        headers=owner_headers,
    )
    assert invalid_window.status_code == 422

    created = client.post("/requests", json=_payload(), headers=owner_headers)
    assert created.status_code == 201
    created_body = created.json()
    request_id = created_body["id"]
    assert created_body["user_id"] == owner.id

    listed = client.get("/requests?dest_city=Lahore&min_price=100000&max_price=200000")
    assert listed.status_code == 200
    assert len(listed.json()) == 1

    fetched = client.get(f"/requests/{request_id}")
    assert fetched.status_code == 200
    assert fetched.json()["id"] == request_id

    forbidden_patch = client.patch(
        f"/requests/{request_id}",
        json={"target_price": 160000},
        headers=other_headers,
    )
    assert forbidden_patch.status_code == 403

    missing_patch = client.patch(
        "/requests/999999",
        json={"target_price": 160000},
        headers=owner_headers,
    )
    assert missing_patch.status_code == 404

    patched = client.patch(
        f"/requests/{request_id}",
        json={"target_price": 155000, "window_end": "2026-01-22T10:00:00"},
        headers=owner_headers,
    )
    assert patched.status_code == 200
    assert patched.json()["target_price"] == 155000

    forbidden_delete = client.delete(f"/requests/{request_id}", headers=other_headers)
    assert forbidden_delete.status_code == 403

    deleted = client.delete(f"/requests/{request_id}", headers=owner_headers)
    assert deleted.status_code == 204

    not_found_after_delete = client.get(f"/requests/{request_id}")
    assert not_found_after_delete.status_code == 404
