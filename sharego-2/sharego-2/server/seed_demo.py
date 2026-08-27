"""Demo seed script — pre-populates the DB for FYP evaluation day.

Usage:
    cd server
    python seed_demo.py          # wipes + seeds
    python seed_demo.py --keep   # seeds without wiping (may conflict on duplicates)
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta

from passlib.context import CryptContext
from sqlmodel import Session, SQLModel

from app.db import engine
from app.models import (
    AuditLog,
    Booking,
    BookingStatus,
    EscrowTx,
    FeatureFlag,
    HandoverEvent,
    KYCProfile,
    MarketListing,
    MarketMeetup,
    MarketOffer,
    Message,
    OfferStatus,
    RequestItem,
    Review,
    Trip,
    User,
    WalletEntry,
)

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=4)
_now = datetime.utcnow()


def _hash(code: str) -> str:
    return _pwd.hash(code)


def seed() -> None:
    keep = "--keep" in sys.argv
    if not keep:
        print("[seed] Dropping all tables...")
        SQLModel.metadata.drop_all(engine)

    print("[seed] Creating tables...")
    SQLModel.metadata.create_all(engine)

    with Session(engine) as s:
        # ── Users ────────────────────────────────────────────
        buyer = User(
            email="buyer@demo.com",
            phone="+923001234567",
            roles_csv="user",
            kyc_status="approved",
            rating_avg=4.5,
            password_hash=_hash("Demo1234"),
        )
        traveler = User(
            email="traveler@demo.com",
            phone="+923009876543",
            roles_csv="user",
            kyc_status="approved",
            rating_avg=4.8,
            password_hash=_hash("Demo1234"),
        )
        seller = User(
            email="seller@demo.com",
            phone="+923005556666",
            roles_csv="user",
            kyc_status="approved",
            rating_avg=4.2,
            password_hash=_hash("Demo1234"),
        )
        admin = User(
            email="admin@demo.com",
            phone="+923000000000",
            roles_csv="admin,user",
            kyc_status="approved",
            rating_avg=0.0,
            password_hash=_hash("Admin1234"),
        )
        pending_user = User(
            email="newuser@demo.com",
            phone="+923001112222",
            roles_csv="user",
            kyc_status="pending",
            rating_avg=0.0,
            password_hash=_hash("Demo1234"),
        )

        for u in [buyer, traveler, seller, admin, pending_user]:
            s.add(u)
        s.commit()
        for u in [buyer, traveler, seller, admin, pending_user]:
            s.refresh(u)

        print(f"[seed] Users: buyer={buyer.id}, traveler={traveler.id}, seller={seller.id}, admin={admin.id}, pending={pending_user.id}")

        # ── KYC Profiles ─────────────────────────────────────
        kyc_approved = KYCProfile(user_id=buyer.id, status="approved", doc_type="cnic", doc_url="demo_cnic.jpg", selfie_url="demo_selfie.jpg")
        kyc_approved2 = KYCProfile(user_id=traveler.id, status="approved", doc_type="passport", doc_url="demo_passport.jpg", selfie_url="demo_selfie2.jpg")
        kyc_pending = KYCProfile(user_id=pending_user.id, status="pending", doc_type="cnic", doc_url="demo_cnic_pending.jpg", selfie_url="demo_selfie_pending.jpg")
        for k in [kyc_approved, kyc_approved2, kyc_pending]:
            s.add(k)
        s.commit()

        # ── Trips ────────────────────────────────────────────
        trip1 = Trip(
            user_id=traveler.id,
            origin_airport="DXB",
            dest_airport="LHE",
            date=_now + timedelta(days=10),
            capacity_kg=15.0,
            fee_pkr=600,
        )
        trip2 = Trip(
            user_id=traveler.id,
            origin_airport="LHR",
            dest_airport="ISB",
            date=_now + timedelta(days=20),
            capacity_kg=10.0,
            fee_pkr=800,
        )
        trip3 = Trip(
            user_id=buyer.id,
            origin_airport="JFK",
            dest_airport="KHI",
            date=_now + timedelta(days=5),
            capacity_kg=8.0,
            fee_pkr=500,
        )
        for t in [trip1, trip2, trip3]:
            s.add(t)
        s.commit()
        for t in [trip1, trip2, trip3]:
            s.refresh(t)

        print(f"[seed] Trips: {trip1.id}, {trip2.id}, {trip3.id}")

        # ── Requests ─────────────────────────────────────────
        req1 = RequestItem(
            user_id=buyer.id,
            product_name="iPhone 16 Pro Max 256GB",
            specs_json=json.dumps({"color": "Desert Titanium", "storage": "256GB"}),
            target_price=350000,
            dest_city="Lahore",
            weight_kg=0.5,
            window_start=_now,
            window_end=_now + timedelta(days=30),
        )
        req2 = RequestItem(
            user_id=buyer.id,
            product_name="Sony WH-1000XM5 Headphones",
            specs_json=json.dumps({"color": "Black"}),
            target_price=55000,
            dest_city="Lahore",
            weight_kg=0.4,
            window_start=_now,
            window_end=_now + timedelta(days=25),
        )
        req3 = RequestItem(
            user_id=pending_user.id,
            product_name="Samsung Galaxy S25 Ultra",
            specs_json=json.dumps({"color": "Titanium Gray", "storage": "512GB"}),
            target_price=280000,
            dest_city="Islamabad",
            weight_kg=0.3,
            window_start=_now,
            window_end=_now + timedelta(days=30),
        )
        for r in [req1, req2, req3]:
            s.add(r)
        s.commit()
        for r in [req1, req2, req3]:
            s.refresh(r)

        print(f"[seed] Requests: {req1.id}, {req2.id}, {req3.id}")

        # ── Booking 1: ACCEPTED (ready for pickup demo) ─────
        pickup_code1 = "111111"
        delivery_code1 = "222222"
        bk1 = Booking(
            trip_id=trip1.id,
            request_id=req1.id,
            status=BookingStatus.ACCEPTED.value,
            waybill="SG-2602-000001",
            pickup_code_hash=_hash(pickup_code1),
            delivery_code_hash=_hash(delivery_code1),
        )
        s.add(bk1)
        s.commit()
        s.refresh(bk1)

        esc1 = EscrowTx(booking_id=bk1.id, amount=350000, currency="PKR", status="hold")
        s.add(esc1)
        s.commit()

        # ── Booking 2: DELIVERY_OK (ready for admin release) ─
        pickup_code2 = "333333"
        delivery_code2 = "444444"
        bk2 = Booking(
            trip_id=trip2.id,
            request_id=req2.id,
            status=BookingStatus.DELIVERY_OK.value,
            waybill="SG-2602-000002",
            pickup_code_hash=None,
            delivery_code_hash=None,
            seal_id="SEAL-DEMO-001",
        )
        s.add(bk2)
        s.commit()
        s.refresh(bk2)

        esc2 = EscrowTx(booking_id=bk2.id, amount=55000, currency="PKR", status="hold")
        s.add(esc2)
        s.commit()

        # Handover events for bk2
        he_pickup = HandoverEvent(
            booking_id=bk2.id,
            type=BookingStatus.PICKUP_OK.value,
            gps_lat=25.2048,
            gps_lng=55.2708,
            photos_paths=json.dumps(["pickup_photo_1.jpg"]),
            seal_id="SEAL-DEMO-001",
            ts=_now - timedelta(days=3),
        )
        he_delivery = HandoverEvent(
            booking_id=bk2.id,
            type=BookingStatus.DELIVERY_OK.value,
            gps_lat=31.5204,
            gps_lng=74.3587,
            photos_paths=json.dumps(["delivery_photo_1.jpg"]),
            seal_id="SEAL-DEMO-001",
            ts=_now - timedelta(hours=6),
        )
        s.add(he_pickup)
        s.add(he_delivery)
        s.commit()

        # ── Booking 3: HOLD_PLACED (for expiry demo) ────────
        bk3 = Booking(
            trip_id=trip1.id,
            request_id=req3.id,
            status=BookingStatus.HOLD_PLACED.value,
            waybill="SG-2602-000003",
            pickup_code_hash=_hash("555555"),
            delivery_code_hash=_hash("666666"),
            created_at=_now - timedelta(hours=50),  # Old enough to expire
        )
        s.add(bk3)
        s.commit()
        s.refresh(bk3)

        esc3 = EscrowTx(booking_id=bk3.id, amount=280000, currency="PKR", status="hold")
        s.add(esc3)
        s.commit()

        print(f"[seed] Bookings: bk1={bk1.id}(ACCEPTED), bk2={bk2.id}(DELIVERY_OK), bk3={bk3.id}(HOLD_PLACED)")

        # ── Marketplace Listings ─────────────────────────────
        lst1 = MarketListing(
            seller_id=seller.id,
            title="MacBook Pro M3 14-inch",
            description="Barely used, 2 months old. 16GB RAM, 512GB SSD. Original box included.",
            category="Electronics",
            condition="Like New",
            location_text="Lahore, Gulberg",
            latitude=31.5204,
            longitude=74.3587,
            ask_price=320000,
            contact_pref="in-app",
            status="active",
        )
        lst2 = MarketListing(
            seller_id=seller.id,
            title="Nike Air Jordan 1 Retro High",
            description="Size 42, Bred colourway, DS (deadstock). With box.",
            category="Fashion",
            condition="New",
            location_text="Lahore, DHA Phase 5",
            latitude=31.4668,
            longitude=74.3779,
            ask_price=35000,
            contact_pref="in-app",
            status="active",
        )
        lst3 = MarketListing(
            seller_id=buyer.id,
            title="Samsung 55-inch QLED TV",
            description="2024 model, perfect condition. Moving abroad, must sell.",
            category="Electronics",
            condition="Good",
            location_text="Islamabad, F-10",
            latitude=33.6844,
            longitude=73.0479,
            ask_price=95000,
            contact_pref="whatsapp",
            status="active",
        )
        lst4 = MarketListing(
            seller_id=traveler.id,
            title="IKEA Study Desk",
            description="White wood desk, 120x60cm. Disassembled for easy transport.",
            category="Home",
            condition="Good",
            location_text="Karachi, Clifton",
            latitude=24.8138,
            longitude=67.0301,
            ask_price=12000,
            contact_pref="in-app",
            status="sold",
        )
        for l in [lst1, lst2, lst3, lst4]:
            s.add(l)
        s.commit()
        for l in [lst1, lst2, lst3, lst4]:
            s.refresh(l)

        print(f"[seed] Listings: {lst1.id}, {lst2.id}, {lst3.id}, {lst4.id}(sold)")

        # ── Offers ───────────────────────────────────────────
        off1 = MarketOffer(
            listing_id=lst1.id,
            from_user_id=buyer.id,
            amount=290000,
            message="Can you do 290k? Cash ready.",
            status=OfferStatus.SENT.value,
        )
        off2 = MarketOffer(
            listing_id=lst1.id,
            from_user_id=pending_user.id,
            amount=300000,
            message="300k final, can pick up today.",
            status=OfferStatus.COUNTERED.value,
        )
        off3 = MarketOffer(
            listing_id=lst2.id,
            from_user_id=buyer.id,
            amount=30000,
            message="30k?",
            status=OfferStatus.ACCEPTED.value,
        )
        off4 = MarketOffer(
            listing_id=lst4.id,
            from_user_id=buyer.id,
            amount=10000,
            message="10k for the desk?",
            status=OfferStatus.ACCEPTED.value,
        )
        for o in [off1, off2, off3, off4]:
            s.add(o)
        s.commit()

        # ── Meetups ──────────────────────────────────────────
        meetup1 = MarketMeetup(
            listing_id=lst2.id,
            buyer_id=buyer.id,
            seller_id=seller.id,
            place_text="McDonald's, DHA Phase 5, Lahore",
            scheduled_ts=_now + timedelta(days=2),
            note="I'll be wearing a red jacket",
        )
        s.add(meetup1)
        s.commit()

        # ── Reviews ──────────────────────────────────────────
        rev1 = Review(
            reviewer_id=buyer.id,
            reviewee_id=traveler.id,
            target_type="booking",
            target_id=bk2.id,
            rating=5,
            comment="Excellent traveler, item arrived in perfect condition!",
        )
        rev2 = Review(
            reviewer_id=traveler.id,
            reviewee_id=buyer.id,
            target_type="booking",
            target_id=bk2.id,
            rating=4,
            comment="Good buyer, clear instructions.",
        )
        rev3 = Review(
            reviewer_id=buyer.id,
            reviewee_id=seller.id,
            target_type="market",
            target_id=lst4.id,
            rating=4,
            comment="Desk was as described. Quick meetup.",
        )
        for r in [rev1, rev2, rev3]:
            s.add(r)
        s.commit()

        # ── Wallet entries (from completed booking #2 escrow sim) ──
        w1 = WalletEntry(user_id=traveler.id, delta=55000, balance_after=55000, reason="escrow_sim_credit", ref_id=f"booking:{bk2.id}")
        s.add(w1)
        s.commit()

        # ── Messages ────────────────────────────────────────
        msg1 = Message(sender_id=buyer.id, receiver_id=traveler.id, content="Hi, when do you land in Lahore?", booking_id=bk1.id, created_at=_now - timedelta(hours=5))
        msg2 = Message(sender_id=traveler.id, receiver_id=buyer.id, content="I land on the 12th, around 3 PM.", booking_id=bk1.id, created_at=_now - timedelta(hours=4))
        msg3 = Message(sender_id=buyer.id, receiver_id=traveler.id, content="Great, I'll meet you at the airport. OTP is ready.", booking_id=bk1.id, created_at=_now - timedelta(hours=3))
        msg4 = Message(sender_id=buyer.id, receiver_id=seller.id, content="Is the MacBook still available?", listing_id=lst1.id, created_at=_now - timedelta(hours=2))
        msg5 = Message(sender_id=seller.id, receiver_id=buyer.id, content="Yes, it's available. Can meet in DHA.", listing_id=lst1.id, created_at=_now - timedelta(hours=1))
        for m in [msg1, msg2, msg3, msg4, msg5]:
            s.add(m)
        s.commit()

        # ── Feature Flags ──────────────────────────────────
        ff1 = FeatureFlag(key="enable_ai_chat", value="true", cohort="all")
        ff2 = FeatureFlag(key="enable_marketplace", value="true", cohort="all")
        ff3 = FeatureFlag(key="enable_escrow_auto_release", value="false", cohort="beta")
        for ff in [ff1, ff2, ff3]:
            s.add(ff)
        s.commit()

        # ── Audit logs ───────────────────────────────────────
        logs = [
            AuditLog(actor=str(buyer.id), action="BOOKING_CREATED", entity=f"booking:{bk1.id}"),
            AuditLog(actor=str(traveler.id), action="BOOKING_ACCEPTED", entity=f"booking:{bk1.id}"),
            AuditLog(actor=str(buyer.id), action="BOOKING_CREATED", entity=f"booking:{bk2.id}"),
            AuditLog(actor=str(traveler.id), action="BOOKING_ACCEPTED", entity=f"booking:{bk2.id}"),
            AuditLog(actor=str(traveler.id), action="BOOKING_PICKUP_VERIFIED", entity=f"booking:{bk2.id}"),
            AuditLog(actor=str(buyer.id), action="BOOKING_DELIVERY_VERIFIED", entity=f"booking:{bk2.id}"),
            AuditLog(actor=str(seller.id), action="LISTING_CREATED", entity=f"listing:{lst1.id}"),
            AuditLog(actor=str(admin.id), action="KYC_APPROVED", entity=f"kyc:{kyc_approved.id}"),
        ]
        for log in logs:
            s.add(log)
        s.commit()

        # Capture IDs before session closes.
        bk1_id, bk2_id, bk3_id = bk1.id, bk2.id, bk3.id

    print()
    print("=== Demo seed complete! ===")
    print()
    print("Demo accounts (all use OTP 123456 in dev mode):")
    print("  buyer@demo.com     — buyer role, has bookings + requests")
    print("  traveler@demo.com  — traveler role, has trips")
    print("  seller@demo.com    — seller role, has marketplace listings")
    print("  admin@demo.com     — admin role, can access admin panel")
    print("  newuser@demo.com   — pending KYC, for verification demo")
    print()
    print(f"Booking #{bk1_id}: ACCEPTED — demo pickup OTP: {pickup_code1}, delivery OTP: {delivery_code1}")
    print(f"Booking #{bk2_id}: DELIVERY_OK — ready for admin escrow release")
    print(f"Booking #{bk3_id}: HOLD_PLACED (50h old) — ready for expiry demo")
    print()
    print("Admin panel: http://localhost:8000/admin/dashboard")


if __name__ == "__main__":
    seed()
