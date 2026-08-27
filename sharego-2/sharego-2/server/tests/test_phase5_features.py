"""Tests for Phase 5 features: scheduler expiry, trip filters, KYC guard, forgot password."""

from datetime import datetime, timedelta

from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel

from app.core.config import get_settings
from app.core.limits import limiter
from app.core.security import create_access_token
from app.db import engine
from app.main import app
from app.models import Booking, BookingStatus, EscrowTx, RequestItem, Trip, User
from app.scheduler import expire_stale_bookings


def _reset():
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)
    limiter._storage.reset()


def _token(email: str) -> str:
    settings = get_settings()
    return create_access_token(subject=email, settings=settings, extra_claims={"roles": ["user"]})


def _auth(email: str) -> dict:
    return {"Authorization": f"Bearer {_token(email)}"}


# ── Scheduler: expire_stale_bookings ─────────────────────────────────


def test_scheduler_expires_old_bookings():
    _reset()
    with Session(engine) as s:
        u = User(email="sched@test.com", roles_csv="user", kyc_status="approved")
        s.add(u)
        s.commit()
        s.refresh(u)

        trip = Trip(user_id=u.id, origin_airport="DXB", dest_airport="LHE", date=datetime.utcnow() + timedelta(days=10), capacity_kg=10)
        s.add(trip)
        s.commit()
        s.refresh(trip)

        req = RequestItem(user_id=u.id, product_name="Test", dest_city="Lahore", weight_kg=1, window_start=datetime.utcnow(), window_end=datetime.utcnow() + timedelta(days=30))
        s.add(req)
        s.commit()
        s.refresh(req)

        # Old booking (60h old) — should be expired.
        old = Booking(trip_id=trip.id, request_id=req.id, status=BookingStatus.HOLD_PLACED.value, waybill="SG-TEST-OLD", created_at=datetime.utcnow() - timedelta(hours=60))
        s.add(old)
        s.commit()
        s.refresh(old)

        esc = EscrowTx(booking_id=old.id, amount=10000, currency="PKR", status="hold")
        s.add(esc)
        s.commit()
        old_id = old.id
        esc_id = esc.id

    # Run the scheduler job.
    expire_stale_bookings()

    with Session(engine) as s:
        booking = s.get(Booking, old_id)
        assert booking.status == BookingStatus.EXPIRED.value
        escrow = s.get(EscrowTx, esc_id)
        assert escrow.status == "refunded"


def test_scheduler_skips_recent_bookings():
    _reset()
    with Session(engine) as s:
        u = User(email="sched2@test.com", roles_csv="user", kyc_status="approved")
        s.add(u)
        s.commit()
        s.refresh(u)

        trip = Trip(user_id=u.id, origin_airport="JFK", dest_airport="ISB", date=datetime.utcnow() + timedelta(days=10), capacity_kg=10)
        s.add(trip)
        s.commit()
        s.refresh(trip)

        req = RequestItem(user_id=u.id, product_name="Test2", dest_city="ISB", weight_kg=1, window_start=datetime.utcnow(), window_end=datetime.utcnow() + timedelta(days=30))
        s.add(req)
        s.commit()
        s.refresh(req)

        # Recent booking (1h old) — should NOT be expired.
        recent = Booking(trip_id=trip.id, request_id=req.id, status=BookingStatus.HOLD_PLACED.value, waybill="SG-TEST-NEW", created_at=datetime.utcnow() - timedelta(hours=1))
        s.add(recent)
        s.commit()
        recent_id = recent.id

    expire_stale_bookings()

    with Session(engine) as s:
        booking = s.get(Booking, recent_id)
        assert booking.status == BookingStatus.HOLD_PLACED.value


# ── Trip list filters ────────────────────────────────────────────────


def test_trip_filters():
    _reset()
    with Session(engine) as s:
        u = User(email="tripfilter@test.com", roles_csv="user", kyc_status="approved")
        s.add(u)
        s.commit()
        s.refresh(u)

        trips = [
            Trip(user_id=u.id, origin_airport="DXB", dest_airport="LHE", date=datetime(2026, 3, 1), capacity_kg=10, status="approved"),
            Trip(user_id=u.id, origin_airport="LHR", dest_airport="ISB", date=datetime(2026, 3, 15), capacity_kg=5, status="approved"),
            Trip(user_id=u.id, origin_airport="DXB", dest_airport="KHI", date=datetime(2026, 4, 1), capacity_kg=20, status="approved"),
        ]
        for t in trips:
            s.add(t)
        s.commit()

    client = TestClient(app)

    # No filters — all 3 trips.
    resp = client.get("/trips", headers=_auth("tripfilter@test.com"))
    assert resp.status_code == 200
    assert len(resp.json()) == 3

    # Filter by origin.
    resp = client.get("/trips?origin=DXB", headers=_auth("tripfilter@test.com"))
    assert len(resp.json()) == 2

    # Filter by dest.
    resp = client.get("/trips?dest=ISB", headers=_auth("tripfilter@test.com"))
    assert len(resp.json()) == 1

    # Filter by min_capacity.
    resp = client.get("/trips?min_capacity=15", headers=_auth("tripfilter@test.com"))
    assert len(resp.json()) == 1
    assert resp.json()[0]["capacity_kg"] == 20


# ── KYC enforcement guard ────────────────────────────────────────────


def test_kyc_guard_blocks_pending_user():
    _reset()
    with Session(engine) as s:
        pending = User(email="pending@test.com", roles_csv="user", kyc_status="pending")
        approved = User(email="approved@test.com", roles_csv="user", kyc_status="approved")
        s.add(pending)
        s.add(approved)
        s.commit()

    client = TestClient(app)

    # Pending user cannot create trip.
    resp = client.post(
        "/trips",
        json={"origin_airport": "DXB", "dest_airport": "LHE", "date": "2026-04-01T12:00:00", "capacity_kg": 10},
        headers=_auth("pending@test.com"),
    )
    assert resp.status_code == 403
    assert "KYC" in resp.json()["error"]["message"]

    # Approved user can create trip.
    resp = client.post(
        "/trips",
        json={"origin_airport": "DXB", "dest_airport": "LHE", "date": "2026-04-01T12:00:00", "capacity_kg": 10},
        headers=_auth("approved@test.com"),
    )
    assert resp.status_code == 201


# ── Forgot password endpoint ─────────────────────────────────────────


def test_forgot_password_existing_user():
    _reset()
    with Session(engine) as s:
        u = User(email="forgot@test.com", roles_csv="user")
        s.add(u)
        s.commit()

    client = TestClient(app)
    resp = client.post("/auth/forgot", json={"email": "forgot@test.com"})
    assert resp.status_code == 200
    data = resp.json()
    assert "otp_dev" in data  # Dev mode returns OTP.
    assert data["otp_dev"] == "123456"


def test_forgot_password_nonexistent_user():
    _reset()
    client = TestClient(app)
    resp = client.post("/auth/forgot", json={"email": "nobody@test.com"})
    assert resp.status_code == 200
    # Should NOT reveal that account doesn't exist.
    assert "otp_dev" not in resp.json()
