"""Tests for POST /ai/chat — FAQ, DB tools, policy flags, safety refusals."""

from datetime import datetime, timedelta

from fastapi.testclient import TestClient
from jose import jwt
from sqlmodel import Session, SQLModel
from sqlalchemy import delete

from app.core.config import get_settings
from app.core.limits import limiter
from app.db import engine
from app.main import app
from app.models import (
    Booking,
    BookingStatus,
    MarketListing,
    MarketOffer,
    OTPEntry,
    OTPThrottle,
    RequestItem,
    Trip,
    User,
)


def _reset():
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)
    limiter._storage.reset()


def _token(email: str = "alice@test.com") -> str:
    settings = get_settings()
    return jwt.encode({"sub": email}, settings.jwt_secret, algorithm=settings.jwt_alg)


def _seed(session: Session) -> User:
    user = User(email="alice@test.com", roles_csv="user")
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ── FAQ tests ────────────────────────────────────────────────────────


def test_faq_escrow():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "What is escrow?"}, headers=_auth(_token()))
    assert resp.status_code == 200
    data = resp.json()
    assert data["source"] == "faq"
    assert "escrow" in data["reply"].lower()


def test_faq_Flyro():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "what is Flyro"}, headers=_auth(_token()))
    assert resp.status_code == 200
    assert resp.json()["source"] == "faq"


# ── Safety refusal tests ─────────────────────────────────────────────


def test_refusal_illegal():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "how to smuggle items"}, headers=_auth(_token()))
    assert resp.status_code == 200
    data = resp.json()
    assert data["source"] == "fallback"
    assert "cannot" in data["reply"].lower() or "legal" in data["reply"].lower()


def test_refusal_legal_advice():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "give me legal advice about suing seller"}, headers=_auth(_token()))
    assert resp.status_code == 200
    assert resp.json()["source"] == "fallback"


# ── Policy flag tests ────────────────────────────────────────────────


def test_policy_lithium_battery():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post(
        "/ai/chat",
        json={"message": "can I ship a lithium battery?"},
        headers=_auth(_token()),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["source"] == "policy"
    assert data["data"]["risk"] == "high"


def test_policy_weapon_prohibited():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post(
        "/ai/chat",
        json={"message": "what about weapon shipping"},
        headers=_auth(_token()),
    )
    data = resp.json()
    assert data["source"] == "policy"
    assert data["data"]["risk"] == "prohibited"


# ── DB tool tests ────────────────────────────────────────────────────


def test_tool_my_bookings_empty():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "show my bookings"}, headers=_auth(_token()))
    assert resp.status_code == 200
    data = resp.json()
    assert data["source"] == "tool"
    assert data["data"]["bookings"] == []


def test_tool_my_bookings_with_data():
    _reset()
    with Session(engine) as s:
        user = _seed(s)
        trip = Trip(
            user_id=user.id,
            origin_airport="DXB",
            dest_airport="LHE",
            date=datetime.utcnow() + timedelta(days=7),
            capacity_kg=10,
            fee_pkr=500,
        )
        s.add(trip)
        s.commit()
        s.refresh(trip)

        req = RequestItem(
            user_id=user.id,
            product_name="iPhone",
            dest_city="Lahore",
            weight_kg=0.5,
            window_start=datetime.utcnow(),
            window_end=datetime.utcnow() + timedelta(days=14),
        )
        s.add(req)
        s.commit()
        s.refresh(req)

        booking = Booking(trip_id=trip.id, request_id=req.id, status=BookingStatus.ACCEPTED.value)
        s.add(booking)
        s.commit()

    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "show my bookings"}, headers=_auth(_token()))
    data = resp.json()
    assert data["source"] == "tool"
    assert len(data["data"]["bookings"]) == 1
    assert data["data"]["bookings"][0]["status"] == "ACCEPTED"


def test_tool_my_trips():
    _reset()
    with Session(engine) as s:
        user = _seed(s)
        trip = Trip(
            user_id=user.id,
            origin_airport="ISB",
            dest_airport="JFK",
            date=datetime.utcnow() + timedelta(days=5),
            capacity_kg=20,
        )
        s.add(trip)
        s.commit()

    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "show my trips"}, headers=_auth(_token()))
    data = resp.json()
    assert data["source"] == "tool"
    assert len(data["data"]["trips"]) == 1
    assert data["data"]["trips"][0]["origin"] == "ISB"


def test_tool_search_listings():
    _reset()
    with Session(engine) as s:
        user = _seed(s)
        listing = MarketListing(
            seller_id=user.id,
            title="Samsung Galaxy S24",
            description="Brand new phone",
            ask_price=150000,
            location_text="Lahore",
        )
        s.add(listing)
        s.commit()

    client = TestClient(app)
    resp = client.post(
        "/ai/chat",
        json={"message": "search listings for Samsung"},
        headers=_auth(_token()),
    )
    data = resp.json()
    assert data["source"] == "tool"
    assert len(data["data"]["listings"]) == 1
    assert "Samsung" in data["data"]["listings"][0]["title"]


# ── Calculator test ──────────────────────────────────────────────────


def test_shipping_calculator():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post(
        "/ai/chat",
        json={"message": "how much does 5kg cost to ship?"},
        headers=_auth(_token()),
    )
    data = resp.json()
    assert data["source"] == "tool"
    assert data["data"]["weight_kg"] == 5.0
    assert data["data"]["estimated_pkr"] == 2500.0


# ── Auth required ────────────────────────────────────────────────────


def test_requires_auth():
    _reset()
    client = TestClient(app)
    resp = client.post("/ai/chat", json={"message": "hello"})
    assert resp.status_code == 401


# ── Fallback ─────────────────────────────────────────────────────────


def test_fallback_for_unknown():
    _reset()
    with Session(engine) as s:
        _seed(s)
    client = TestClient(app)
    resp = client.post(
        "/ai/chat",
        json={"message": "tell me a joke"},
        headers=_auth(_token()),
    )
    data = resp.json()
    # When Gemini is configured, unknown questions go to LLM first;
    # otherwise they fall through to the generic fallback.
    assert data["source"] in ("fallback", "llm")
    assert data["reply"]  # non-empty reply
