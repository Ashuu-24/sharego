from __future__ import annotations

import json
import logging
import math
from datetime import datetime
from secrets import randbelow

from fastapi import HTTPException, status
from passlib.context import CryptContext
from sqlmodel import Session, select

from app.core.audit import write_audit_log
from app.core.config import get_settings
from app.models import MarketListing, MarketMeetup, MarketOffer, OfferStatus
from app.schemas.marketplace import (
    MARKETPLACE_DISCLAIMER,
    ListingCreate,
    ListingRead,
    ListingUpdate,
    MarkSoldPayload,
    MeetupCreate,
    MeetupRead,
    OfferAction,
    OfferCreate,
    OfferRead,
)

_settings = get_settings()
_pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=max(4, _settings.otp_bcrypt_rounds),
)

LISTING_STATUSES = {"active", "paused", "sold", "removed"}


def _utcnow() -> datetime:
    return datetime.utcnow()


def _normalize_currency(currency: str) -> str:
    return currency.strip().upper()


def _json_load_list(value: str | None) -> list[str]:
    if not value:
        return []
    try:
        parsed = json.loads(value)
        if isinstance(parsed, list):
            return [str(item) for item in parsed if str(item).strip()]
    except json.JSONDecodeError:
        logging.warning("Failed to parse JSON list: %s", value)
    return []


def _json_dump_list(value: list[str]) -> str:
    return json.dumps([item.strip() for item in value if item.strip()])


def _listing_or_404(session: Session, listing_id: int) -> MarketListing:
    listing = session.get(MarketListing, listing_id)
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    return listing


def _offer_or_404(session: Session, offer_id: int) -> MarketOffer:
    offer = session.get(MarketOffer, offer_id)
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    return offer


def _meetup_or_404(session: Session, meetup_id: int) -> MarketMeetup:
    meetup = session.get(MarketMeetup, meetup_id)
    if not meetup:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meetup not found")
    return meetup


def _to_listing_read(listing: MarketListing) -> ListingRead:
    return ListingRead(
        id=listing.id,
        seller_id=listing.seller_id,
        title=listing.title,
        description=listing.description,
        photos_paths=_json_load_list(listing.photos_paths),
        category=listing.category,
        condition=listing.condition,
        location_text=listing.location_text,
        latitude=listing.latitude,
        longitude=listing.longitude,
        ask_price=listing.ask_price,
        currency=listing.currency,
        contact_pref=listing.contact_pref,
        status=listing.status,
        created_at=listing.created_at,
        updated_at=listing.updated_at,
        marketplace_disclaimer=MARKETPLACE_DISCLAIMER,
    )


def _to_offer_read(offer: MarketOffer) -> OfferRead:
    return OfferRead(
        id=offer.id,
        listing_id=offer.listing_id,
        from_user_id=offer.from_user_id,
        amount=offer.amount,
        currency=offer.currency,
        message=offer.message,
        status=offer.status,
        ts=offer.ts,
        marketplace_disclaimer=MARKETPLACE_DISCLAIMER,
    )


def _to_meetup_read(meetup: MarketMeetup, *, otp_dev: str | None = None) -> MeetupRead:
    return MeetupRead(
        id=meetup.id,
        listing_id=meetup.listing_id,
        buyer_id=meetup.buyer_id,
        seller_id=meetup.seller_id,
        place_text=meetup.place_text,
        scheduled_ts=meetup.scheduled_ts,
        confirmed_ts=meetup.confirmed_ts,
        note=meetup.note,
        marketplace_disclaimer=MARKETPLACE_DISCLAIMER,
        otp_dev=otp_dev,
    )


def _distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    radius = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius * c


def create_listing(
    session: Session,
    *,
    seller_id: int,
    data: ListingCreate,
    actor: str | None = None,
    request_id: str | None = None,
) -> ListingRead:
    listing = MarketListing(
        seller_id=seller_id,
        title=data.title.strip(),
        description=data.description.strip(),
        photos_paths=_json_dump_list(data.photos_paths),
        category=data.category.strip() if data.category else None,
        condition=data.condition.strip() if data.condition else None,
        location_text=data.location_text.strip() if data.location_text else None,
        latitude=data.latitude,
        longitude=data.longitude,
        ask_price=data.ask_price,
        currency=_normalize_currency(data.currency),
        contact_pref=data.contact_pref.strip() if data.contact_pref else None,
        status="active",
        updated_at=_utcnow(),
    )
    session.add(listing)
    session.commit()
    session.refresh(listing)
    write_audit_log(
        session,
        actor=actor or str(seller_id),
        action="MARKET_LISTING_CREATED",
        entity=f"market_listing:{listing.id}",
        request_id=request_id,
        after={"status": listing.status, "ask_price": listing.ask_price},
    )
    return _to_listing_read(listing)


def list_listings(
    session: Session,
    *,
    query: str | None = None,
    category: str | None = None,
    near: tuple[float, float, float] | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
    status_filter: str | None = "active",
    seller_id: int | None = None,
) -> list[ListingRead]:
    stmt = select(MarketListing)
    if seller_id is not None:
        stmt = stmt.where(MarketListing.seller_id == seller_id)
    if status_filter:
        if status_filter not in LISTING_STATUSES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid listing status filter")
        stmt = stmt.where(MarketListing.status == status_filter)
    if category:
        stmt = stmt.where(MarketListing.category == category)
    if min_price is not None:
        stmt = stmt.where(MarketListing.ask_price >= min_price)
    if max_price is not None:
        stmt = stmt.where(MarketListing.ask_price <= max_price)
    if query:
        pattern = f"%{query.strip()}%"
        stmt = stmt.where(
            MarketListing.title.ilike(pattern)
            | MarketListing.description.ilike(pattern)
            | MarketListing.location_text.ilike(pattern)
        )

    listings = session.exec(stmt.order_by(MarketListing.created_at.desc())).all()
    if near:
        lat, lng, radius_km = near
        listings = [
            listing
            for listing in listings
            if listing.latitude is not None
            and listing.longitude is not None
            and _distance_km(lat, lng, listing.latitude, listing.longitude) <= radius_km
        ]
    return [_to_listing_read(item) for item in listings]


def get_listing(session: Session, *, listing_id: int) -> ListingRead:
    return _to_listing_read(_listing_or_404(session, listing_id))


def update_listing(
    session: Session,
    *,
    listing_id: int,
    seller_id: int,
    data: ListingUpdate,
    actor: str | None = None,
    request_id: str | None = None,
) -> ListingRead:
    listing = _listing_or_404(session, listing_id)
    if listing.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only seller can update listing")

    updates = data.model_dump(exclude_unset=True)
    new_status = updates.get("status")
    if new_status is not None:
        if listing.status == "sold":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Sold listing cannot be reopened")
        allowed = {
            "active": {"paused", "removed", "active"},
            "paused": {"active", "removed", "paused"},
            "removed": {"removed"},
        }.get(listing.status, set())
        if new_status not in allowed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"message": "Illegal listing transition", "from": listing.status, "to": new_status},
            )

    if "title" in updates:
        listing.title = updates["title"].strip()
    if "description" in updates:
        listing.description = updates["description"].strip()
    if "photos_paths" in updates:
        listing.photos_paths = _json_dump_list(updates["photos_paths"] or [])
    if "category" in updates:
        listing.category = updates["category"].strip() if updates["category"] else None
    if "condition" in updates:
        listing.condition = updates["condition"].strip() if updates["condition"] else None
    if "location_text" in updates:
        listing.location_text = updates["location_text"].strip() if updates["location_text"] else None
    if "latitude" in updates:
        listing.latitude = updates["latitude"]
    if "longitude" in updates:
        listing.longitude = updates["longitude"]
    if "ask_price" in updates:
        listing.ask_price = updates["ask_price"]
    if "currency" in updates and updates["currency"] is not None:
        listing.currency = _normalize_currency(updates["currency"])
    if "contact_pref" in updates:
        listing.contact_pref = updates["contact_pref"].strip() if updates["contact_pref"] else None
    if "status" in updates and updates["status"] is not None:
        listing.status = updates["status"]
    listing.updated_at = _utcnow()
    session.add(listing)
    session.commit()
    session.refresh(listing)

    write_audit_log(
        session,
        actor=actor or str(seller_id),
        action="MARKET_LISTING_UPDATED",
        entity=f"market_listing:{listing.id}",
        request_id=request_id,
        after={"status": listing.status},
    )
    return _to_listing_read(listing)


def mark_sold(
    session: Session,
    *,
    listing_id: int,
    seller_id: int,
    payload: MarkSoldPayload | None = None,
    actor: str | None = None,
    request_id: str | None = None,
) -> ListingRead:
    listing = _listing_or_404(session, listing_id)
    if listing.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only seller can mark sold")
    if listing.status in {"removed"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Removed listing cannot be sold")
    if listing.status == "sold":
        return _to_listing_read(listing)

    if payload and payload.offer_id is not None:
        offer = _offer_or_404(session, payload.offer_id)
        if offer.listing_id != listing.id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Offer does not belong to listing")

    listing.status = "sold"
    listing.updated_at = _utcnow()
    session.add(listing)
    session.commit()
    session.refresh(listing)
    write_audit_log(
        session,
        actor=actor or str(seller_id),
        action="MARKET_LISTING_SOLD",
        entity=f"market_listing:{listing.id}",
        request_id=request_id,
        after={"status": listing.status, "note": payload.note if payload else None},
    )
    return _to_listing_read(listing)


def create_offer(
    session: Session,
    *,
    listing_id: int,
    from_user_id: int,
    data: OfferCreate,
    actor: str | None = None,
    request_id: str | None = None,
) -> OfferRead:
    listing = _listing_or_404(session, listing_id)
    if listing.seller_id == from_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Seller cannot offer on own listing")
    if listing.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Offers allowed only on active listings")

    prior = session.exec(
        select(MarketOffer).where(
            MarketOffer.listing_id == listing_id,
            MarketOffer.from_user_id == from_user_id,
            MarketOffer.status.in_([OfferStatus.SENT.value, OfferStatus.COUNTERED.value]),
        )
    ).all()
    for old in prior:
        old.status = OfferStatus.WITHDRAWN.value
        session.add(old)

    offer = MarketOffer(
        listing_id=listing.id,
        from_user_id=from_user_id,
        amount=data.amount,
        currency=_normalize_currency(data.currency),
        message=data.message.strip() if data.message else None,
        status=OfferStatus.SENT.value,
        ts=_utcnow(),
    )
    session.add(offer)
    session.commit()
    session.refresh(offer)
    write_audit_log(
        session,
        actor=actor or str(from_user_id),
        action="MARKET_OFFER_CREATED",
        entity=f"market_offer:{offer.id}",
        request_id=request_id,
        after={"status": offer.status, "amount": offer.amount},
    )
    return _to_offer_read(offer)


def list_offers_for_listing(session: Session, *, listing_id: int, user_id: int) -> list[OfferRead]:
    listing = _listing_or_404(session, listing_id)
    if listing.seller_id == user_id:
        offers = session.exec(
            select(MarketOffer)
            .where(MarketOffer.listing_id == listing_id)
            .order_by(MarketOffer.ts.asc())
        ).all()
        return [_to_offer_read(item) for item in offers]

    offers = session.exec(
        select(MarketOffer)
        .where(MarketOffer.listing_id == listing_id, MarketOffer.from_user_id == user_id)
        .order_by(MarketOffer.ts.asc())
    ).all()
    if not offers:
        # Buyers need to open the thread before their first offer exists; return an empty
        # thread instead of 403 so the app can show the compose UI on active listings.
        if listing.status == "active":
            return []
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the seller or an offer participant can view this thread",
        )
    return [_to_offer_read(item) for item in offers]


def _ensure_seller_for_offer(session: Session, offer: MarketOffer, seller_id: int) -> MarketListing:
    listing = _listing_or_404(session, offer.listing_id)
    if listing.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only seller can perform this action")
    return listing


def counter_offer(
    session: Session,
    *,
    offer_id: int,
    seller_id: int,
    data: OfferAction,
    actor: str | None = None,
    request_id: str | None = None,
) -> OfferRead:
    offer = _offer_or_404(session, offer_id)
    _ensure_seller_for_offer(session, offer, seller_id)
    if offer.status not in {OfferStatus.SENT.value, OfferStatus.COUNTERED.value}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal offer transition", "from": offer.status, "to": OfferStatus.COUNTERED.value},
        )
    if data.amount is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Counter amount is required")

    offer.amount = data.amount
    if data.message is not None:
        offer.message = data.message.strip() if data.message else None
    offer.status = OfferStatus.COUNTERED.value
    offer.ts = _utcnow()
    session.add(offer)
    session.commit()
    session.refresh(offer)
    write_audit_log(
        session,
        actor=actor or str(seller_id),
        action="MARKET_OFFER_COUNTERED",
        entity=f"market_offer:{offer.id}",
        request_id=request_id,
        after={"status": offer.status, "amount": offer.amount},
    )
    return _to_offer_read(offer)


def accept_offer(
    session: Session,
    *,
    offer_id: int,
    seller_id: int,
    actor: str | None = None,
    request_id: str | None = None,
) -> OfferRead:
    offer = _offer_or_404(session, offer_id)
    listing = _ensure_seller_for_offer(session, offer, seller_id)
    if offer.status not in {OfferStatus.SENT.value, OfferStatus.COUNTERED.value}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal offer transition", "from": offer.status, "to": OfferStatus.ACCEPTED.value},
        )

    offer.status = OfferStatus.ACCEPTED.value
    offer.ts = _utcnow()
    listing.status = "paused"
    listing.updated_at = _utcnow()
    session.add(offer)
    session.add(listing)

    others = session.exec(
        select(MarketOffer).where(
            MarketOffer.listing_id == offer.listing_id,
            MarketOffer.id != offer.id,
            MarketOffer.status.in_([OfferStatus.SENT.value, OfferStatus.COUNTERED.value]),
        )
    ).all()
    for other in others:
        other.status = OfferStatus.DECLINED.value
        other.ts = _utcnow()
        session.add(other)

    session.commit()
    session.refresh(offer)
    write_audit_log(
        session,
        actor=actor or str(seller_id),
        action="MARKET_OFFER_ACCEPTED",
        entity=f"market_offer:{offer.id}",
        request_id=request_id,
        after={"status": offer.status, "listing_status": listing.status},
    )
    return _to_offer_read(offer)


def decline_offer(
    session: Session,
    *,
    offer_id: int,
    seller_id: int,
    data: OfferAction | None = None,
    actor: str | None = None,
    request_id: str | None = None,
) -> OfferRead:
    offer = _offer_or_404(session, offer_id)
    _ensure_seller_for_offer(session, offer, seller_id)
    if offer.status not in {OfferStatus.SENT.value, OfferStatus.COUNTERED.value}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal offer transition", "from": offer.status, "to": OfferStatus.DECLINED.value},
        )
    offer.status = OfferStatus.DECLINED.value
    if data and data.message is not None:
        offer.message = data.message.strip() if data.message else None
    offer.ts = _utcnow()
    session.add(offer)
    session.commit()
    session.refresh(offer)
    write_audit_log(
        session,
        actor=actor or str(seller_id),
        action="MARKET_OFFER_DECLINED",
        entity=f"market_offer:{offer.id}",
        request_id=request_id,
        after={"status": offer.status},
    )
    return _to_offer_read(offer)


def withdraw_offer(
    session: Session,
    *,
    offer_id: int,
    from_user_id: int,
    data: OfferAction | None = None,
    actor: str | None = None,
    request_id: str | None = None,
) -> OfferRead:
    offer = _offer_or_404(session, offer_id)
    if offer.from_user_id != from_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only offer creator can withdraw")
    if offer.status not in {OfferStatus.SENT.value, OfferStatus.COUNTERED.value}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal offer transition", "from": offer.status, "to": OfferStatus.WITHDRAWN.value},
        )
    offer.status = OfferStatus.WITHDRAWN.value
    if data and data.message is not None:
        offer.message = data.message.strip() if data.message else None
    offer.ts = _utcnow()
    session.add(offer)
    session.commit()
    session.refresh(offer)
    write_audit_log(
        session,
        actor=actor or str(from_user_id),
        action="MARKET_OFFER_WITHDRAWN",
        entity=f"market_offer:{offer.id}",
        request_id=request_id,
        after={"status": offer.status},
    )
    return _to_offer_read(offer)


def _generate_otp() -> str:
    return f"{randbelow(900000) + 100000:06d}"


def create_meetup(
    session: Session,
    *,
    buyer_id: int,
    data: MeetupCreate,
    actor: str | None = None,
    request_id: str | None = None,
) -> tuple[MeetupRead, str]:
    listing = _listing_or_404(session, data.listing_id)
    if buyer_id == listing.seller_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Seller cannot create buyer meetup")

    accepted = session.exec(
        select(MarketOffer).where(
            MarketOffer.listing_id == listing.id,
            MarketOffer.from_user_id == buyer_id,
            MarketOffer.status == OfferStatus.ACCEPTED.value,
        )
    ).first()
    if not accepted:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Accepted offer is required before meetup")

    otp = _generate_otp()
    meetup = MarketMeetup(
        listing_id=listing.id,
        buyer_id=buyer_id,
        seller_id=listing.seller_id,
        place_text=data.place_text.strip(),
        scheduled_ts=data.scheduled_ts,
        otp_hash=_pwd_context.hash(otp),
        confirmed_ts=None,
        note=None,
    )
    session.add(meetup)
    session.commit()
    session.refresh(meetup)
    write_audit_log(
        session,
        actor=actor or str(buyer_id),
        action="MARKET_MEETUP_CREATED",
        entity=f"market_meetup:{meetup.id}",
        request_id=request_id,
        after={"listing_id": meetup.listing_id, "buyer_id": meetup.buyer_id, "seller_id": meetup.seller_id},
    )
    return _to_meetup_read(meetup, otp_dev=otp), otp


def get_meetup(session: Session, *, meetup_id: int, user_id: int) -> MeetupRead:
    meetup = _meetup_or_404(session, meetup_id)
    if user_id not in {meetup.buyer_id, meetup.seller_id}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only participants can view meetup")
    return _to_meetup_read(meetup)


def confirm_meetup(
    session: Session,
    *,
    meetup_id: int,
    user_id: int,
    otp: str,
    actor: str | None = None,
    request_id: str | None = None,
) -> MeetupRead:
    meetup = _meetup_or_404(session, meetup_id)
    if user_id not in {meetup.buyer_id, meetup.seller_id}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only participants can confirm meetup")
    if meetup.confirmed_ts is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Meetup already confirmed")
    if not meetup.otp_hash or not _pwd_context.verify(otp, meetup.otp_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid meetup OTP")

    meetup.confirmed_ts = _utcnow()
    meetup.otp_hash = None
    session.add(meetup)
    session.commit()
    session.refresh(meetup)
    write_audit_log(
        session,
        actor=actor or str(user_id),
        action="MARKET_MEETUP_CONFIRMED",
        entity=f"market_meetup:{meetup.id}",
        request_id=request_id,
        after={"confirmed_ts": meetup.confirmed_ts.isoformat()},
    )
    return _to_meetup_read(meetup)
