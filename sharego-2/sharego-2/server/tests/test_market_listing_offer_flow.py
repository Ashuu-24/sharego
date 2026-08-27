from datetime import datetime, timedelta

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


def auth_headers(email: str, roles: list[str]) -> dict[str, str]:
    token = create_access_token(
        subject=email,
        settings=get_settings(),
        extra_claims={"roles": roles},
    )
    return {"Authorization": f"Bearer {token}"}


def seed_users() -> dict[str, str]:
    with Session(engine) as session:
        seller = User(email="market-seller@example.com", phone="", roles_csv="user", kyc_status="approved")
        buyer = User(email="market-buyer@example.com", phone="", roles_csv="user", kyc_status="approved")
        intruder = User(email="market-intruder@example.com", phone="", roles_csv="user", kyc_status="approved")
        session.add(seller)
        session.add(buyer)
        session.add(intruder)
        session.commit()
        return {
            "seller_email": seller.email,
            "buyer_email": buyer.email,
            "intruder_email": intruder.email,
        }


def _assert_disclaimer(payload: dict) -> None:
    assert "marketplace_disclaimer" in payload
    text = payload["marketplace_disclaimer"].lower()
    assert "no auctions" in text
    assert "does not provide escrow" in text
    assert "delivery" in text
    assert "courier" in text


def _assert_error_envelope(response, status_code: int) -> dict:
    assert response.status_code == status_code
    body = response.json()
    assert "error" in body
    assert body["error"]["code"] == f"http_{status_code}"
    assert "message" in body["error"]
    return body


def test_market_listing_offer_flow() -> None:
    reset_db()
    users = seed_users()
    client = TestClient(app)

    seller_headers = auth_headers(users["seller_email"], ["user"])
    buyer_headers = auth_headers(users["buyer_email"], ["user"])
    intruder_headers = auth_headers(users["intruder_email"], ["user"])

    listing_res = client.post(
        "/market/listings",
        headers=seller_headers,
        json={
            "title": "PS5 Disk Edition",
            "description": "Used but in excellent condition",
            "photos_paths": ["assets/1 ps5.png", "assets/2 ps5.png"],
            "category": "Electronics",
            "condition": "Used",
            "location_text": "Lahore, Pakistan",
            "latitude": 31.5204,
            "longitude": 74.3587,
            "ask_price": 120000,
            "currency": "PKR",
            "contact_pref": "in-app-chat",
        },
    )
    assert listing_res.status_code == 201
    listing = listing_res.json()
    listing_id = listing["id"]
    _assert_disclaimer(listing)
    assert listing["status"] == "active"

    # Buyer (and any user) may open the offer thread on an active listing before the first
    # offer exists — server returns an empty list instead of 403.
    empty_thread = client.get(f"/market/listings/{listing_id}/offers", headers=buyer_headers)
    assert empty_thread.status_code == 200
    assert empty_thread.json() == []

    list_res = client.get("/market/listings")
    assert list_res.status_code == 200
    assert any(item["id"] == listing_id for item in list_res.json())
    _assert_disclaimer(list_res.json()[0])

    offer_res = client.post(
        f"/market/listings/{listing_id}/offer",
        headers=buyer_headers,
        json={"amount": 110000, "currency": "PKR", "message": "Can pick up today"},
    )
    assert offer_res.status_code == 201
    offer = offer_res.json()
    offer_id = offer["id"]
    _assert_disclaimer(offer)
    assert offer["status"] == "SENT"

    # Unauthorized actions.
    _assert_error_envelope(
        client.post(
        f"/market/offers/{offer_id}/counter",
        headers=intruder_headers,
        json={"amount": 115000, "message": "Counter"},
    ),
        403,
    )
    _assert_error_envelope(
        client.post(f"/market/offers/{offer_id}/accept", headers=intruder_headers),
        403,
    )
    _assert_error_envelope(
        client.post(f"/market/offers/{offer_id}/withdraw", headers=intruder_headers),
        403,
    )
    _assert_error_envelope(
        client.post(
            f"/market/offers/{offer_id}/counter",
            headers=buyer_headers,
            json={"amount": 115000, "message": "Buyer cannot counter"},
        ),
        403,
    )
    _assert_error_envelope(
        client.post(f"/market/offers/{offer_id}/decline", headers=buyer_headers),
        403,
    )

    # Third party with no offers sees an empty thread on an active listing (no other users' data).
    intruder_thread = client.get(f"/market/listings/{listing_id}/offers", headers=intruder_headers)
    assert intruder_thread.status_code == 200
    assert intruder_thread.json() == []
    seller_thread = client.get(f"/market/listings/{listing_id}/offers", headers=seller_headers)
    assert seller_thread.status_code == 200
    _assert_disclaimer(seller_thread.json()[0])
    buyer_thread = client.get(f"/market/listings/{listing_id}/offers", headers=buyer_headers)
    assert buyer_thread.status_code == 200
    assert all(item["from_user_id"] == buyer_thread.json()[0]["from_user_id"] for item in buyer_thread.json())

    counter_res = client.post(
        f"/market/offers/{offer_id}/counter",
        headers=seller_headers,
        json={"amount": 115000, "message": "Final counter"},
    )
    assert counter_res.status_code == 200
    counter = counter_res.json()
    assert counter["status"] == "COUNTERED"
    _assert_disclaimer(counter)

    accepted_res = client.post(f"/market/offers/{offer_id}/accept", headers=seller_headers)
    assert accepted_res.status_code == 200
    accepted = accepted_res.json()
    assert accepted["status"] == "ACCEPTED"
    _assert_disclaimer(accepted)

    # Invalid transitions once accepted.
    _assert_error_envelope(
        client.post(
        f"/market/offers/{offer_id}/counter",
        headers=seller_headers,
        json={"amount": 116000, "message": "late counter"},
    ),
        400,
    )
    _assert_error_envelope(
        client.post(
        f"/market/offers/{offer_id}/withdraw",
        headers=buyer_headers,
        json={"message": "late withdraw"},
    ),
        400,
    )

    meetup_res = client.post(
        "/market/meetups",
        headers=buyer_headers,
        json={
            "listing_id": listing_id,
            "place_text": "Emporium Mall gate 2",
            "scheduled_ts": (datetime.utcnow() + timedelta(days=1)).isoformat(),
        },
    )
    assert meetup_res.status_code == 201
    meetup = meetup_res.json()
    _assert_disclaimer(meetup)
    meetup_id = meetup["id"]
    otp = meetup.get("otp_dev")
    assert otp is not None and len(otp) == 6

    _assert_error_envelope(
        client.get(f"/market/meetups/{meetup_id}", headers=intruder_headers),
        403,
    )

    bad_confirm = client.post(
        f"/market/meetups/{meetup_id}/confirm",
        headers=seller_headers,
        json={"otp": "000000"},
    )
    _assert_error_envelope(bad_confirm, 400)

    confirm_res = client.post(
        f"/market/meetups/{meetup_id}/confirm",
        headers=seller_headers,
        json={"otp": otp},
    )
    assert confirm_res.status_code == 200
    confirmed = confirm_res.json()
    assert confirmed["confirmed_ts"] is not None
    _assert_disclaimer(confirmed)

    _assert_error_envelope(
        client.post(
        f"/market/meetups/{meetup_id}/confirm",
        headers=buyer_headers,
        json={"otp": otp},
    ),
        400,
    )

    sold_res = client.post(
        f"/market/listings/{listing_id}/mark_sold",
        headers=seller_headers,
        json={"offer_id": offer_id, "note": "Meetup done"},
    )
    assert sold_res.status_code == 200
    sold = sold_res.json()
    assert sold["status"] == "sold"
    _assert_disclaimer(sold)

    # No new offers on sold listing.
    _assert_error_envelope(
        client.post(
        f"/market/listings/{listing_id}/offer",
        headers=buyer_headers,
        json={"amount": 105000, "currency": "PKR", "message": "new offer"},
    ),
        400,
    )


def test_market_listings_filters_query_category_near_price_status() -> None:
    reset_db()
    users = seed_users()
    client = TestClient(app)
    seller_headers = auth_headers(users["seller_email"], ["user"])
    buyer_headers = auth_headers(users["buyer_email"], ["user"])

    l1 = client.post(
        "/market/listings",
        headers=seller_headers,
        json={
            "title": "Apple MacBook Pro",
            "description": "M2, 16GB RAM",
            "photos_paths": ["assets/1 mc.png"],
            "category": "Electronics",
            "condition": "Used",
            "location_text": "Lahore, Pakistan",
            "latitude": 31.5204,
            "longitude": 74.3587,
            "ask_price": 150000,
            "currency": "PKR",
            "contact_pref": "chat",
        },
    )
    assert l1.status_code == 201
    id1 = l1.json()["id"]

    l2 = client.post(
        "/market/listings",
        headers=seller_headers,
        json={
            "title": "PS5 Disk Edition",
            "description": "Excellent condition",
            "photos_paths": ["assets/1 ps5.png"],
            "category": "Gaming",
            "condition": "Used",
            "location_text": "Karachi, Pakistan",
            "latitude": 24.8607,
            "longitude": 67.0011,
            "ask_price": 120000,
            "currency": "PKR",
            "contact_pref": "chat",
        },
    )
    assert l2.status_code == 201
    id2 = l2.json()["id"]

    query_res = client.get("/market/listings", params={"query": "MacBook"})
    assert query_res.status_code == 200
    query_ids = {item["id"] for item in query_res.json()}
    assert id1 in query_ids and id2 not in query_ids

    category_res = client.get("/market/listings", params={"category": "Gaming"})
    assert category_res.status_code == 200
    category_ids = {item["id"] for item in category_res.json()}
    assert id2 in category_ids and id1 not in category_ids

    price_res = client.get("/market/listings", params={"min": 130000, "max": 200000})
    assert price_res.status_code == 200
    price_ids = {item["id"] for item in price_res.json()}
    assert id1 in price_ids and id2 not in price_ids

    near_res = client.get("/market/listings", params={"near": "31.52,74.35,50"})
    assert near_res.status_code == 200
    near_ids = {item["id"] for item in near_res.json()}
    assert id1 in near_ids and id2 not in near_ids

    offer = client.post(
        f"/market/listings/{id1}/offer",
        headers=buyer_headers,
        json={"amount": 140000, "currency": "PKR", "message": "offer"},
    )
    assert offer.status_code == 201
    offer_id = offer.json()["id"]
    accepted = client.post(f"/market/offers/{offer_id}/accept", headers=seller_headers)
    assert accepted.status_code == 200

    paused_res = client.get("/market/listings", params={"status": "paused"})
    assert paused_res.status_code == 200
    paused_ids = {item["id"] for item in paused_res.json()}
    assert id1 in paused_ids and id2 not in paused_ids

    active_res = client.get("/market/listings")
    assert active_res.status_code == 200
    active_ids = {item["id"] for item in active_res.json()}
    assert id1 not in active_ids and id2 in active_ids
