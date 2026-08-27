from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, col, func, select

from app.api.deps import get_current_user_dep, get_session_dep
from app.models import (
    Booking,
    BookingStatus,
    MarketListing,
    MarketOffer,
    OfferStatus,
    RequestItem,
    Review,
    Trip,
    User,
)
from app.schemas.reviews import ReviewCreate, ReviewRead

router = APIRouter(prefix="/reviews", tags=["reviews"])


# ── helpers ──────────────────────────────────────────────────────────


def _validate_booking_review(session: Session, user: User, target_id: int) -> int:
    """Ensure the booking is RELEASED and the user is a participant.
    Returns the reviewee_id (the *other* party)."""
    booking = session.get(Booking, target_id)
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.status != BookingStatus.RELEASED.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reviews are only allowed after the booking is RELEASED",
        )

    trip = session.get(Trip, booking.trip_id)
    request_item = session.get(RequestItem, booking.request_id)
    if not trip or not request_item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Related trip/request missing")

    traveler_id = trip.user_id
    buyer_id = request_item.user_id

    if user.id == buyer_id:
        return traveler_id
    if user.id == traveler_id:
        return buyer_id

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Only booking participants can leave reviews",
    )


def _validate_market_review(session: Session, user: User, target_id: int) -> int:
    """Ensure the listing is SOLD and the user is a participant.
    Returns the reviewee_id."""
    listing = session.get(MarketListing, target_id)
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    if listing.status != "sold":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reviews are only allowed after the listing is marked SOLD",
        )

    seller_id = listing.seller_id

    # Try to find the buyer from an accepted offer first.
    accepted_offer = session.exec(
        select(MarketOffer).where(
            MarketOffer.listing_id == target_id,
            MarketOffer.status == OfferStatus.ACCEPTED.value,
        )
    ).first()
    buyer_id = accepted_offer.from_user_id if accepted_offer else None

    if user.id == seller_id and buyer_id:
        return buyer_id
    if user.id == buyer_id:
        return seller_id

    # Fallback: if no accepted offer, allow any offer participant to review the seller
    # (listing was marked sold manually without accepting a specific offer)
    if user.id != seller_id:
        any_offer = session.exec(
            select(MarketOffer).where(
                MarketOffer.listing_id == target_id,
                MarketOffer.from_user_id == user.id,
            )
        ).first()
        if any_offer:
            return seller_id

    # Allow seller to review the most recent offer maker if no accepted offer
    if user.id == seller_id and not buyer_id:
        latest_offer = session.exec(
            select(MarketOffer)
            .where(MarketOffer.listing_id == target_id)
            .order_by(MarketOffer.ts.desc())
        ).first()
        if latest_offer:
            return latest_offer.from_user_id

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Only deal participants can leave reviews",
    )


def _update_rating_avg(session: Session, reviewee_id: int) -> None:
    """Recalculate and persist rating_avg on the User row."""
    result = session.exec(
        select(func.avg(col(Review.rating))).where(Review.reviewee_id == reviewee_id)
    ).one()
    avg = round(float(result), 2) if result else 0.0
    user = session.get(User, reviewee_id)
    if user:
        user.rating_avg = avg
        session.add(user)


# ── routes ───────────────────────────────────────────────────────────


@router.post("", response_model=ReviewRead, status_code=status.HTTP_201_CREATED)
async def create_review(
    payload: ReviewCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    # Prevent duplicate reviews (one review per user per target).
    existing = session.exec(
        select(Review).where(
            Review.reviewer_id == user.id,
            Review.target_type == payload.target_type,
            Review.target_id == payload.target_id,
        )
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have already reviewed this item",
        )

    # Validate eligibility and determine reviewee.
    if payload.target_type == "booking":
        expected_reviewee = _validate_booking_review(session, user, payload.target_id)
    else:
        expected_reviewee = _validate_market_review(session, user, payload.target_id)

    # Use server-determined reviewee (ignore client-provided value if mismatched).
    reviewee_id = expected_reviewee

    review = Review(
        reviewer_id=user.id,
        reviewee_id=reviewee_id,
        target_type=payload.target_type,
        target_id=payload.target_id,
        rating=payload.rating,
        comment=payload.comment,
    )
    session.add(review)
    session.commit()
    session.refresh(review)

    # Update the reviewee's average rating.
    _update_rating_avg(session, reviewee_id)
    session.commit()

    review_data = ReviewRead.model_validate(review)
    review_data.reviewer_name = user.name or user.email
    return review_data


@router.get("", response_model=list[ReviewRead])
async def list_reviews(
    target_type: str | None = Query(default=None, description="Filter: 'booking' or 'market'"),
    target_id: int | None = Query(default=None, description="Filter by specific target ID"),
    reviewee_id: int | None = Query(default=None, description="Filter by reviewee (user being reviewed)"),
    session: Session = Depends(get_session_dep),
):
    stmt = select(Review)
    if target_type:
        stmt = stmt.where(Review.target_type == target_type)
    if target_id is not None:
        stmt = stmt.where(Review.target_id == target_id)
    if reviewee_id is not None:
        stmt = stmt.where(Review.reviewee_id == reviewee_id)
    stmt = stmt.order_by(Review.ts.desc())  # type: ignore[union-attr]
    reviews = session.exec(stmt).all()

    # Enrich with reviewer names
    user_cache: dict[int, User | None] = {}
    result = []
    for r in reviews:
        data = ReviewRead.model_validate(r)
        if r.reviewer_id not in user_cache:
            user_cache[r.reviewer_id] = session.get(User, r.reviewer_id)
        reviewer = user_cache.get(r.reviewer_id)
        if reviewer:
            data.reviewer_name = reviewer.name or reviewer.email
        result.append(data)
    return result
