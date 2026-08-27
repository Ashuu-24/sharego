from datetime import datetime
import re

from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, select

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db import engine
from app.main import app
from app.domain.escrow.service import _add_wallet_entry
from app.models import AuditLog, Booking, EscrowTx, RequestItem, Trip, User, WalletEntry


def reset_db() -> None:
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)


def auth_headers(email: str, roles: list[str]) -> dict[str, str]:
    token = create_access_token(
        subject=email,
        settings=get_settings(),
        extra_claims={"roles": roles},
    )
    return {"Authorization": f"Bearer {token}"}


def seed_users_trip_request() -> dict[str, int | str]:
    with Session(engine) as session:
        buyer = User(email="buyer@example.com", phone="", roles_csv="user", kyc_status="approved")
        traveler = User(email="traveler@example.com", phone="", roles_csv="user", rating_avg=4.8, kyc_status="approved")
        admin = User(email="admin@example.com", phone="", roles_csv="admin")
        session.add(buyer)
        session.add(traveler)
        session.add(admin)
        session.commit()
        session.refresh(buyer)
        session.refresh(traveler)
        session.refresh(admin)

        trip = Trip(
            user_id=traveler.id,
            origin_airport="KHI",
            dest_airport="LHE",
            date=datetime(2026, 2, 14, 12, 30, 0),
            capacity_kg=6.0,
            fee_pkr=5000,
        )
        request = RequestItem(
            user_id=buyer.id,
            product_name="PS5",
            specs_json='{"edition":"disc"}',
            target_price=175000,
            dest_city="Lahore",
            weight_kg=4.2,
            window_start=datetime(2026, 2, 10, 0, 0, 0),
            window_end=datetime(2026, 2, 20, 0, 0, 0),
            declaration_path=None,
        )
        session.add(trip)
        session.add(request)
        session.commit()
        session.refresh(trip)
        session.refresh(request)

        # Give buyer wallet balance for booking
        _add_wallet_entry(session, user_id=buyer.id, delta=200000, reason="demo_credit", ref_id="test_seed")
        seeded = {
            "buyer_id": buyer.id,
            "buyer_email": buyer.email,
            "traveler_id": traveler.id,
            "traveler_email": traveler.email,
            "admin_id": admin.id,
            "admin_email": admin.email,
            "trip_id": trip.id,
            "request_id": request.id,
        }
    return seeded


def test_booking_flow_end_to_end() -> None:
    reset_db()
    data = seed_users_trip_request()
    client = TestClient(app)

    buyer_headers = auth_headers(data["buyer_email"], ["user"])
    traveler_headers = auth_headers(data["traveler_email"], ["user"])
    admin_headers = auth_headers(data["admin_email"], ["admin"])

    created = client.post(
        "/bookings",
        json={
            "trip_id": data["trip_id"],
            "request_id": data["request_id"],
            "amount": 180000,
            "currency": "PKR",
        },
        headers=buyer_headers,
    )
    assert created.status_code == 201
    created_body = created.json()
    booking_id = created_body["id"]
    pickup_otp = created_body["pickup_otp_dev"]
    delivery_otp = created_body["delivery_otp_dev"]
    assert created_body["status"] == "HOLD_PLACED"
    assert re.fullmatch(r"^SG-\d{4}-\d{6}$", created_body["waybill"]) is not None
    assert pickup_otp and delivery_otp

    accepted = client.post(f"/bookings/{booking_id}/accept", headers=traveler_headers)
    assert accepted.status_code == 200
    assert accepted.json()["status"] == "ACCEPTED"

    pickup = client.post(
        f"/bookings/{booking_id}/pickup/verify",
        json={
            "otp": pickup_otp,
            "gps_lat": 31.5204,
            "gps_lng": 74.3587,
            "photo_paths": ["media/pickup1.jpg"],
            "seal_id": "SEAL-101",
        },
        headers=traveler_headers,
    )
    assert pickup.status_code == 200
    assert pickup.json()["status"] == "PICKUP_OK"

    delivery = client.post(
        f"/bookings/{booking_id}/delivery/verify",
        json={
            "otp": delivery_otp,
            "gps_lat": 31.5204,
            "gps_lng": 74.3587,
            "photo_paths": ["media/delivery1.jpg"],
            "seal_id": "SEAL-101",
        },
        headers=buyer_headers,
    )
    assert delivery.status_code == 200
    assert delivery.json()["status"] == "DELIVERY_OK"

    released = client.post(f"/admin/escrow/{booking_id}/release", headers=admin_headers)
    assert released.status_code == 200
    assert released.json()["status"] == "RELEASED"

    with Session(engine) as session:
        booking = session.get(Booking, booking_id)
        assert booking is not None
        assert booking.status == "RELEASED"

        escrow = session.exec(select(EscrowTx).where(EscrowTx.booking_id == booking_id)).first()
        assert escrow is not None
        assert escrow.status == "released"

        traveler_entries = session.exec(
            select(WalletEntry).where(
                WalletEntry.user_id == data["traveler_id"],
                WalletEntry.reason == "escrow_release",
            )
        ).all()
        assert len(traveler_entries) == 1
        assert traveler_entries[0].delta == 180000

        actions = {
            row.action
            for row in session.exec(select(AuditLog).where(AuditLog.entity == f"booking:{booking_id}")).all()
        }
        expected_actions = {
            "BOOKING_CREATED",
            "BOOKING_ACCEPTED",
            "BOOKING_PICKUP_VERIFIED",
            "BOOKING_DELIVERY_VERIFIED",
            "ESCROW_RELEASED",
        }
        assert expected_actions.issubset(actions)
