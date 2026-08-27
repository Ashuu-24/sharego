from datetime import datetime

from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, select

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db import engine
from app.main import app
from app.domain.escrow.service import _add_wallet_entry
from app.models import AuditLog, RequestItem, Trip, User


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


def seed_context() -> dict[str, int | str]:
    with Session(engine) as session:
        buyer = User(email="buyer2@example.com", phone="", roles_csv="user", kyc_status="approved")
        traveler = User(email="traveler2@example.com", phone="", roles_csv="user", kyc_status="approved")
        intruder = User(email="intruder@example.com", phone="", roles_csv="user", kyc_status="approved")
        admin = User(email="admin2@example.com", phone="", roles_csv="admin")
        session.add(buyer)
        session.add(traveler)
        session.add(intruder)
        session.add(admin)
        session.commit()
        session.refresh(buyer)
        session.refresh(traveler)
        session.refresh(intruder)
        session.refresh(admin)

        trip = Trip(
            user_id=traveler.id,
            origin_airport="ISB",
            dest_airport="LHE",
            date=datetime(2026, 3, 5, 12, 0, 0),
            capacity_kg=8.0,
            fee_pkr=3000,
        )
        request = RequestItem(
            user_id=buyer.id,
            product_name="Camera Lens",
            specs_json=None,
            target_price=50000,
            dest_city="Lahore",
            weight_kg=1.5,
            window_start=datetime(2026, 3, 1, 0, 0, 0),
            window_end=datetime(2026, 3, 10, 0, 0, 0),
            declaration_path=None,
        )
        session.add(trip)
        session.add(request)
        session.commit()
        session.refresh(trip)
        session.refresh(request)

        # Give buyer wallet balance for booking tests
        _add_wallet_entry(session, user_id=buyer.id, delta=500000, reason="demo_credit", ref_id="test_seed")

        seeded = {
            "buyer_email": buyer.email,
            "traveler_email": traveler.email,
            "intruder_email": intruder.email,
            "admin_email": admin.email,
            "trip_id": trip.id,
            "request_id": request.id,
        }
    return seeded


def create_booking(client: TestClient, headers: dict[str, str], trip_id: int, request_id: int) -> dict:
    response = client.post(
        "/bookings",
        json={"trip_id": trip_id, "request_id": request_id, "amount": 55000, "currency": "PKR"},
        headers=headers,
    )
    assert response.status_code == 201
    return response.json()


def test_booking_illegal_transitions_and_guards() -> None:
    reset_db()
    data = seed_context()
    client = TestClient(app)

    buyer_headers = auth_headers(data["buyer_email"], ["user"])
    traveler_headers = auth_headers(data["traveler_email"], ["user"])
    intruder_headers = auth_headers(data["intruder_email"], ["user"])
    admin_headers = auth_headers(data["admin_email"], ["admin"])

    unauth = client.post(
        "/bookings",
        json={"trip_id": data["trip_id"], "request_id": data["request_id"], "amount": 55000, "currency": "PKR"},
    )
    assert unauth.status_code == 401

    created_body = create_booking(client, buyer_headers, data["trip_id"], data["request_id"])
    booking_id = created_body["id"]
    pickup_otp = created_body["pickup_otp_dev"]
    delivery_otp = created_body["delivery_otp_dev"]

    # Uninvolved user must be denied on booking actions.
    assert client.post(f"/bookings/{booking_id}/accept", headers=intruder_headers).status_code == 403
    assert client.post(f"/bookings/{booking_id}/decline", headers=intruder_headers).status_code == 403
    assert client.post(f"/bookings/{booking_id}/cancel", headers=intruder_headers).status_code == 403
    assert (
        client.post(
            f"/bookings/{booking_id}/pickup/verify",
            json={
                "otp": pickup_otp,
                "gps_lat": 0.0,
                "gps_lng": 0.0,
                "photo_paths": ["media/pickup.jpg"],
                "seal_id": "SEAL-2",
            },
            headers=intruder_headers,
        ).status_code
        == 403
    )
    assert (
        client.post(
            f"/bookings/{booking_id}/delivery/verify",
            json={
                "otp": delivery_otp,
                "gps_lat": 0.0,
                "gps_lng": 0.0,
                "photo_paths": ["media/delivery.jpg"],
                "seal_id": "SEAL-2",
            },
            headers=intruder_headers,
        ).status_code
        == 403
    )

    accepted = client.post(f"/bookings/{booking_id}/accept", headers=traveler_headers)
    assert accepted.status_code == 200

    # Delivery before pickup remains an illegal transition for buyer.
    early_delivery = client.post(
        f"/bookings/{booking_id}/delivery/verify",
        json={
            "otp": delivery_otp,
            "gps_lat": 0.0,
            "gps_lng": 0.0,
            "photo_paths": ["media/delivery.jpg"],
            "seal_id": None,
        },
        headers=buyer_headers,
    )
    assert early_delivery.status_code == 400

    picked = client.post(
        f"/bookings/{booking_id}/pickup/verify",
        json={
            "otp": pickup_otp,
            "gps_lat": 0.0,
            "gps_lng": 0.0,
            "photo_paths": ["media/pickup.jpg"],
            "seal_id": "SEAL-2",
        },
        headers=traveler_headers,
    )
    assert picked.status_code == 200

    # Non-buyer cannot verify delivery.
    non_buyer_delivery = client.post(
        f"/bookings/{booking_id}/delivery/verify",
        json={
            "otp": delivery_otp,
            "gps_lat": 0.0,
            "gps_lng": 0.0,
            "photo_paths": ["media/delivery.jpg"],
            "seal_id": "SEAL-2",
        },
        headers=intruder_headers,
    )
    assert non_buyer_delivery.status_code == 403

    bad_release = client.post(f"/admin/escrow/{booking_id}/release", headers=admin_headers)
    assert bad_release.status_code == 400

    forbidden_admin_action = client.post(f"/admin/escrow/{booking_id}/refund", headers=buyer_headers)
    assert forbidden_admin_action.status_code == 403

    missing = client.post("/bookings/999999/accept", headers=traveler_headers)
    assert missing.status_code == 404


def test_booking_cancel_and_expire_stub() -> None:
    reset_db()
    data = seed_context()
    client = TestClient(app)

    buyer_headers = auth_headers(data["buyer_email"], ["user"])
    traveler_headers = auth_headers(data["traveler_email"], ["user"])
    intruder_headers = auth_headers(data["intruder_email"], ["user"])
    admin_headers = auth_headers(data["admin_email"], ["admin"])

    created = create_booking(client, buyer_headers, data["trip_id"], data["request_id"])
    booking_id = created["id"]

    assert client.post(f"/bookings/{booking_id}/cancel", headers=intruder_headers).status_code == 403
    assert client.post(f"/bookings/{booking_id}/cancel", headers=traveler_headers).status_code == 403

    cancelled = client.post(f"/bookings/{booking_id}/cancel", headers=buyer_headers)
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "CANCELLED"

    # Expire endpoint is an admin stub to mirror upcoming scheduler behavior.
    created_2 = create_booking(client, buyer_headers, data["trip_id"], data["request_id"])
    booking_id_2 = created_2["id"]
    expired = client.post(f"/bookings/{booking_id_2}/expire", headers=admin_headers)
    assert expired.status_code == 200
    assert expired.json()["status"] == "EXPIRED"

    with Session(engine) as session:
        actions = {
            row.action
            for row in session.exec(
                select(AuditLog).where(AuditLog.entity.in_([f"booking:{booking_id}", f"booking:{booking_id_2}"]))
            ).all()
        }
        assert "BOOKING_CANCELLED" in actions
        assert "BOOKING_EXPIRED" in actions


def test_decline_and_refund_write_audit_logs() -> None:
    reset_db()
    data = seed_context()
    client = TestClient(app)

    buyer_headers = auth_headers(data["buyer_email"], ["user"])
    traveler_headers = auth_headers(data["traveler_email"], ["user"])
    admin_headers = auth_headers(data["admin_email"], ["admin"])

    created = create_booking(client, buyer_headers, data["trip_id"], data["request_id"])
    booking_id = created["id"]

    declined = client.post(f"/bookings/{booking_id}/decline", headers=traveler_headers)
    assert declined.status_code == 200
    assert declined.json()["status"] == "CANCELLED"

    refunded = client.post(f"/admin/escrow/{booking_id}/refund", headers=admin_headers)
    assert refunded.status_code == 200
    assert refunded.json()["status"] == "CANCELLED"

    with Session(engine) as session:
        actions = {
            row.action
            for row in session.exec(select(AuditLog).where(AuditLog.entity == f"booking:{booking_id}")).all()
        }
        assert "BOOKING_DECLINED" in actions
        assert "ESCROW_REFUNDED" in actions
