from datetime import datetime

from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db import engine
from app.main import app
from app.models import RequestItem, Trip, User


def reset_db() -> None:
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)


def seed_matching_data() -> tuple[int, int]:
    with Session(engine) as session:
        traveler_a = User(email="traveler_a@example.com", phone="", roles_csv="user", rating_avg=4.3)
        traveler_b = User(email="traveler_b@example.com", phone="", roles_csv="user", rating_avg=4.9)
        buyer = User(email="buyer@example.com", phone="", roles_csv="user", rating_avg=4.1)
        session.add(traveler_a)
        session.add(traveler_b)
        session.add(buyer)
        session.commit()
        session.refresh(traveler_a)
        session.refresh(traveler_b)
        session.refresh(buyer)

        trip_a = Trip(
            user_id=traveler_a.id,
            origin_airport="KHI",
            dest_airport="LHE",
            date=datetime(2026, 1, 12, 12, 0, 0),
            capacity_kg=7.0,
            fee_pkr=3000,
        )
        trip_b = Trip(
            user_id=traveler_b.id,
            origin_airport="ISB",
            dest_airport="LHE",
            date=datetime(2026, 1, 12, 12, 0, 0),
            capacity_kg=10.0,
            fee_pkr=3500,
        )
        trip_c = Trip(
            user_id=traveler_b.id,
            origin_airport="LHE",
            dest_airport="KHI",
            date=datetime(2026, 1, 13, 10, 0, 0),
            capacity_kg=10.0,
            fee_pkr=3500,
        )
        session.add(trip_a)
        session.add(trip_b)
        session.add(trip_c)
        session.commit()
        session.refresh(trip_a)
        session.refresh(trip_b)

        request_match = RequestItem(
            user_id=buyer.id,
            product_name="PS5",
            specs_json='{"edition":"disc"}',
            target_price=170000,
            dest_city="Lahore",
            weight_kg=4.5,
            window_start=datetime(2026, 1, 10, 0, 0, 0),
            window_end=datetime(2026, 1, 14, 0, 0, 0),
            declaration_path=None,
        )
        request_other = RequestItem(
            user_id=buyer.id,
            product_name="Camera",
            specs_json=None,
            target_price=45000,
            dest_city="Karachi",
            weight_kg=1.2,
            window_start=datetime(2026, 1, 10, 0, 0, 0),
            window_end=datetime(2026, 1, 20, 0, 0, 0),
            declaration_path=None,
        )
        session.add(request_match)
        session.add(request_other)
        session.commit()
        session.refresh(request_match)
        return request_match.id, trip_b.id


def test_matching_suggestions_bidirectional_and_query_validation() -> None:
    reset_db()
    request_id, trip_id = seed_matching_data()
    client = TestClient(app)
    token = create_access_token(subject="buyer@example.com", settings=get_settings(), extra_claims={"roles": ["user"]})
    headers = {"Authorization": f"Bearer {token}"}

    unauthorized = client.get(f"/matching/suggest?requestId={request_id}")
    assert unauthorized.status_code == 401

    by_request = client.get(f"/matching/suggest?requestId={request_id}", headers=headers)
    assert by_request.status_code == 200
    by_request_body = by_request.json()
    assert by_request_body["requestId"] == request_id
    assert len(by_request_body["trips"]) >= 2
    # Same date closeness tie must prefer higher traveler rating.
    assert by_request_body["trips"][0]["user_id"] != by_request_body["trips"][1]["user_id"]
    assert by_request_body["trips"][0]["id"] == trip_id

    by_trip = client.get(f"/matching/suggest?tripId={trip_id}", headers=headers)
    assert by_trip.status_code == 200
    by_trip_body = by_trip.json()
    assert by_trip_body["tripId"] == trip_id
    request_destinations = [item["dest_city"] for item in by_trip_body["requests"]]
    assert "Lahore" in request_destinations
    assert "Karachi" not in request_destinations

    none_params = client.get("/matching/suggest", headers=headers)
    assert none_params.status_code == 400

    both_params = client.get(f"/matching/suggest?requestId={request_id}&tripId={trip_id}", headers=headers)
    assert both_params.status_code == 400

    missing_request = client.get("/matching/suggest?requestId=999999", headers=headers)
    assert missing_request.status_code == 404

    missing_trip = client.get("/matching/suggest?tripId=999999", headers=headers)
    assert missing_trip.status_code == 404
