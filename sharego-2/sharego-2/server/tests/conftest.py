"""Shared test fixtures for all test modules.

CRITICAL: The DB_URL override below MUST stay before any app imports.
Without it, tests use the production database and `_reset()` calls in
individual test files will DROP ALL TABLES, destroying real user data.
"""
from __future__ import annotations

import os

# ── Isolate tests to a separate database file ──────────────────────────
os.environ["DB_URL"] = "sqlite:///./test_Flyro.db"

# Clear cached settings so the overridden DB_URL takes effect.
from app.core.config import get_settings  # noqa: E402
get_settings.cache_clear()

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlmodel import Session, SQLModel  # noqa: E402

from app.core.security import create_access_token  # noqa: E402
from app.db import engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import User  # noqa: E402


@pytest.fixture()
def reset_db():
    """Drop and recreate all tables before a test."""
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)
    yield


@pytest.fixture()
def client():
    """FastAPI test client."""
    return TestClient(app)


@pytest.fixture()
def db_session():
    """Raw SQLModel session (auto-closed)."""
    with Session(engine) as session:
        yield session


def create_user(
    email: str,
    *,
    roles_csv: str = "user",
    kyc_status: str = "approved",
    rating_avg: float = 0.0,
) -> User:
    """Insert a user row and return the refreshed instance."""
    with Session(engine) as session:
        user = User(
            email=email,
            phone="",
            roles_csv=roles_csv,
            kyc_status=kyc_status,
            rating_avg=rating_avg,
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return user


def auth_headers(email: str, roles: list[str] | None = None) -> dict[str, str]:
    """Build an Authorization header with a valid JWT."""
    token = create_access_token(
        subject=email,
        settings=get_settings(),
        extra_claims={"roles": roles or ["user"]},
    )
    return {"Authorization": f"Bearer {token}"}
