from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlmodel import Session, col, select

from app.api.deps import (
    get_current_user_dep,
    get_request_id_dep,
    get_session_dep,
    get_settings_dep,
    enforce_kyc_approved,
)

from app.core.config import Settings
from app.core.limits import limiter

from app.domain.marketplace.service import (
    accept_offer,
    confirm_meetup,
    counter_offer,
    create_listing,
    create_meetup,
    create_offer,
    decline_offer,
    get_listing,
    get_meetup,
    list_listings,
    list_offers_for_listing,
    mark_sold,
    update_listing,
    withdraw_offer,
)

from app.models import MarketListing, User

from app.schemas.marketplace import (
    ListingCreate,
    ListingRead,
    ListingUpdate,
    MarkSoldPayload,
    MeetupConfirm,
    MeetupCreate,
    MeetupRead,
    OfferAction,
    OfferCreate,
    OfferRead,
)

from app.services.notifications import push

router = APIRouter(prefix="/market", tags=["marketplace"])


# =========================================================
# CATEGORIES
# =========================================================

@router.get("/categories")
async def get_categories():
    """Returns list of available marketplace categories."""
    return [
        "Electronics",
        "Fashion",
        "Home",
        "Sports",
        "Books",
        "Vehicles",
        "Other",
    ]


# =========================================================
# LISTINGS (GET)
# =========================================================

@router.get("/listings", response_model=list[ListingRead])
async def get_listings(
    query: str = Query(None),
    category: str = Query(None),
    min_price: float = Query(None),
    max_price: float = Query(None),
    status: str = Query("active"),
    near: str = Query(None),  # Format: "lat,lng,radius_km"
    seller_id: int = Query(None),
    session: Session = Depends(get_session_dep),
):
    """
    Get marketplace listings with optional filters.
    """

    near_tuple = None

    if near:
        try:
            parts = near.split(",")

            if len(parts) != 3:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid 'near' parameter format. Use: 'lat,lng,radius_km'",
                )

            lat = float(parts[0])
            lng = float(parts[1])
            radius = float(parts[2])

            near_tuple = (lat, lng, radius)

        except (ValueError, IndexError):
            raise HTTPException(
                status_code=400,
                detail="Invalid 'near' parameter format. Use: 'lat,lng,radius_km'",
            )

    try:
        listings = list_listings(
            session,
            query=query,
            category=category,
            near=near_tuple,
            min_price=min_price,
            max_price=max_price,
            status_filter=status,
            seller_id=seller_id,
        )

        return listings

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load listings: {str(e)}",
        )


@router.get("/listings/mine", response_model=list[ListingRead])
async def get_my_listings(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """
    Get all listings created by the current user.
    """

    try:
        listings = list_listings(
            session,
            seller_id=user.id,
            status_filter=None,
        )

        return listings

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load your listings: {str(e)}",
        )


@router.get("/listings/{listing_id}", response_model=ListingRead)
async def get_single_listing(
    listing_id: int,
    session: Session = Depends(get_session_dep),
):
    """Get details of a specific listing."""

    try:
        return get_listing(
            session,
            listing_id=listing_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load listing: {str(e)}",
        )


@router.get(
    "/listings/{listing_id}/offers",
    response_model=list[OfferRead],
)
async def get_listing_offers(
    listing_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """Get all offers for a listing (seller only)."""

    try:
        return list_offers_for_listing(
            session,
            listing_id=listing_id,
            user_id=user.id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load offers: {str(e)}",
        )


# =========================================================
# LISTINGS (CREATE / UPDATE)
# =========================================================

@router.post(
    "/listings",
    response_model=ListingRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_new_listing(
    payload: ListingCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    """Create a new marketplace listing."""

    enforce_kyc_approved(user)

    try:
        return create_listing(
            session,
            seller_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create listing: {str(e)}",
        )


@router.patch(
    "/listings/{listing_id}",
    response_model=ListingRead,
)
async def update_single_listing(
    listing_id: int,
    payload: ListingUpdate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    """Update a listing."""

    try:
        return update_listing(
            session,
            listing_id=listing_id,
            seller_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update listing: {str(e)}",
        )


# =========================================================
# OFFERS
# =========================================================

@router.post(
    "/listings/{listing_id}/offer",
    response_model=OfferRead,
    status_code=status.HTTP_201_CREATED,
)
async def post_offer(
    listing_id: int,
    payload: OfferCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    enforce_kyc_approved(user)

    try:
        return create_offer(
            session,
            listing_id=listing_id,
            from_user_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create offer: {str(e)}",
        )


@router.post("/offers/{offer_id}/counter", response_model=OfferRead)
async def post_offer_counter(
    offer_id: int,
    payload: OfferAction,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    try:
        return counter_offer(
            session,
            offer_id=offer_id,
            seller_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to counter offer: {str(e)}",
        )


@router.post("/offers/{offer_id}/accept", response_model=OfferRead)
async def post_offer_accept(
    offer_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    try:
        offer = accept_offer(
            session,
            offer_id=offer_id,
            seller_id=user.id,
            actor=str(user.id),
            request_id=request_id,
        )

        # Notification to buyer
        push(
            session,
            user_id=offer.buyer_id,
            type="marketplace",
            title="Offer Accepted 🎉",
            body=f"Your offer #{offer_id} was accepted by the seller.",
            route=f"/market/offer/{offer_id}",
        )

        return offer

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to accept offer: {str(e)}",
        )


@router.post("/offers/{offer_id}/decline", response_model=OfferRead)
async def post_offer_decline(
    offer_id: int,
    payload: OfferAction | None = None,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    try:
        offer = decline_offer(
            session,
            offer_id=offer_id,
            seller_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

        # Notification to buyer
        push(
            session,
            user_id=offer.buyer_id,
            type="marketplace",
            title="Offer Declined ❌",
            body=f"Your offer #{offer_id} was declined by the seller.",
            route=f"/market/offer/{offer_id}",
        )

        return offer

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to decline offer: {str(e)}",
        )


@router.post("/offers/{offer_id}/withdraw", response_model=OfferRead)
async def post_offer_withdraw(
    offer_id: int,
    payload: OfferAction | None = None,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    try:
        return withdraw_offer(
            session,
            offer_id=offer_id,
            from_user_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to withdraw offer: {str(e)}",
        )


# =========================================================
# MARK SOLD
# =========================================================

@router.api_route(
    "/listings/{listing_id}/mark_sold",
    methods=["POST", "PATCH"],
    response_model=ListingRead,
)
async def mark_listing_sold(
    listing_id: int,
    payload: MarkSoldPayload | None = None,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    try:
        listing = mark_sold(
            session,
            listing_id=listing_id,
            seller_id=user.id,
            payload=payload,
            actor=str(user.id),
            request_id=request_id,
        )

        return listing

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to mark listing as sold: {str(e)}",
        )


# =========================================================
# MEETUPS
# =========================================================

@router.post(
    "/meetups",
    response_model=MeetupRead,
    status_code=status.HTTP_201_CREATED,
)
async def post_meetup(
    payload: MeetupCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
    settings: Settings = Depends(get_settings_dep),
):
    try:
        meetup, _otp = create_meetup(
            session,
            buyer_id=user.id,
            data=payload,
            actor=str(user.id),
            request_id=request_id,
        )

        if settings.env != "dev":
            meetup.otp_dev = None

        return meetup

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create meetup: {str(e)}",
        )


@router.post(
    "/meetups/{meetup_id}/confirm",
    response_model=MeetupRead,
)
async def post_meetup_confirm(
    request: Request,
    meetup_id: int,
    payload: MeetupConfirm,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    try:
        return confirm_meetup(
            session,
            meetup_id=meetup_id,
            user_id=user.id,
            otp=payload.otp,
            actor=str(user.id),
            request_id=request_id,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to confirm meetup: {str(e)}",
        )