from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlmodel import Session

from app.api.deps import get_current_user_dep, get_request_id_dep, get_session_dep, get_settings_dep, enforce_kyc_approved
from app.core.config import Settings
from app.core.limits import limiter
from app.domain.bookings.service import (
    accept_booking as accept_booking_service,
    cancel_booking as cancel_booking_service,
    create_booking as create_booking_service,
    create_booking_update as create_booking_update_service,
    decline_booking as decline_booking_service,
    expire_booking_manual,
    get_booking as get_booking_service,
    list_booking_updates as list_booking_updates_service,
    list_bookings_for_user,
)
from app.domain.handover.service import verify_delivery, verify_pickup
from app.models import Booking, RequestItem, Trip, User
from app.schemas.booking_updates import BookingUpdateCreate, BookingUpdateRead
from app.schemas.bookings import BookingCreate, BookingRead, BookingVerifyDelivery, BookingVerifyPickup
from app.services.notifications import push  # ← NEW

router = APIRouter(prefix="/bookings", tags=["bookings"])


def _is_admin(user: User) -> bool:
    return "admin" in user.roles or "ops" in user.roles


@router.get("", response_model=list[BookingRead])
async def list_bookings(
    trip_id: int | None = Query(None, description="Filter bookings by trip ID"),
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    return list_bookings_for_user(session, actor_id=user.id, is_admin=_is_admin(user), trip_id=trip_id)


@router.get("/{booking_id}", response_model=BookingRead)
async def get_booking(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    return get_booking_service(session, booking_id=booking_id, actor_id=user.id, is_admin=_is_admin(user))


@router.post("", response_model=BookingRead, status_code=201)
async def create_booking(
    payload: BookingCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
    settings: Settings = Depends(get_settings_dep),
):
    enforce_kyc_approved(user)
    result = create_booking_service(
        session,
        buyer_id=user.id,
        data=payload,
        actor=str(user.id),
        request_id=request_id,
    )
    if settings.env != "dev":
        result.pickup_otp_dev = None
        result.delivery_otp_dev = None
    return result


@router.post("/{booking_id}/accept", response_model=BookingRead)
async def accept_booking(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    enforce_kyc_approved(user)
    return accept_booking_service(
        session,
        booking_id=booking_id,
        traveler_id=user.id,
        actor=str(user.id),
        request_id=request_id,
    )


@router.post("/{booking_id}/decline", response_model=BookingRead)
async def decline_booking(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    return decline_booking_service(
        session,
        booking_id=booking_id,
        traveler_id=user.id,
        actor=str(user.id),
        request_id=request_id,
    )


@router.post("/{booking_id}/cancel", response_model=BookingRead)
async def cancel_booking(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    return cancel_booking_service(
        session,
        booking_id=booking_id,
        initiator_id=user.id,
        actor=str(user.id),
        request_id=request_id,
    )


@router.post("/{booking_id}/expire", response_model=BookingRead)
async def expire_booking(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    if not _is_admin(user):
        raise HTTPException(status_code=403, detail="Admin access required")
    return expire_booking_manual(
        session,
        booking_id=booking_id,
        actor=str(user.id),
        request_id=request_id,
    )


@router.post("/{booking_id}/pickup/verify", response_model=BookingRead)
@limiter.limit("5/minute")
async def pickup_verify(
    request: Request,
    booking_id: int,
    payload: BookingVerifyPickup,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    enforce_kyc_approved(user)
    verify_pickup(
        session,
        booking_id=booking_id,
        traveler_id=user.id,
        otp=payload.otp,
        gps_lat=payload.gps_lat,
        gps_lng=payload.gps_lng,
        photo_paths=payload.photo_paths,
        seal_id=payload.seal_id,
        request_id=request_id,
    )

    # ── Notification: Buyer ko batao item pick ho gaya ───────────────
    _booking = session.get(Booking, booking_id)
    if _booking:
        _request = session.get(RequestItem, _booking.request_id)
        if _request:
            push(
                session,
                user_id=_request.user_id,
                type="booking",
                title="Item Picked Up ✈️",
                body=f"Booking #{booking_id} — traveler has picked up your item.",
                route=f"/booking/{booking_id}/timeline",
            )
    # ────────────────────────────────────────────────────────────────

    return get_booking_service(session, booking_id=booking_id, actor_id=user.id, is_admin=_is_admin(user))


@router.post("/{booking_id}/delivery/verify", response_model=BookingRead)
@limiter.limit("5/minute")
async def delivery_verify(
    request: Request,
    booking_id: int,
    payload: BookingVerifyDelivery,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    enforce_kyc_approved(user)
    verify_delivery(
        session,
        booking_id=booking_id,
        buyer_id=user.id,
        otp=payload.otp,
        gps_lat=payload.gps_lat,
        gps_lng=payload.gps_lng,
        photo_paths=payload.photo_paths,
        seal_id=payload.seal_id,
        request_id=request_id,
    )

    # ── Notification: Dono ko batao delivery complete ────────────────
    _booking = session.get(Booking, booking_id)
    if _booking:
        _request = session.get(RequestItem, _booking.request_id)
        _trip = session.get(Trip, _booking.trip_id)
        if _request:
            push(
                session,
                user_id=_request.user_id,
                type="booking",
                title="Delivery Confirmed ✅",
                body=f"Booking #{booking_id} delivered! Escrow funds releasing.",
                route=f"/booking/{booking_id}/timeline",
            )
        if _trip:
            push(
                session,
                user_id=_trip.user_id,
                type="wallet",
                title="Payment Released 💰",
                body=f"Booking #{booking_id} complete. Your earnings are in your wallet.",
                route="/wallet",
            )
    # ────────────────────────────────────────────────────────────────

    return get_booking_service(session, booking_id=booking_id, actor_id=user.id, is_admin=_is_admin(user))


@router.post("/{booking_id}/updates", response_model=BookingUpdateRead, status_code=201)
async def post_booking_update(
    booking_id: int,
    payload: BookingUpdateCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    return create_booking_update_service(
        session,
        booking_id=booking_id,
        user_id=user.id,
        data=payload,
        request_id=request_id,
    )


@router.get("/{booking_id}/updates", response_model=list[BookingUpdateRead])
async def get_booking_updates(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    return list_booking_updates_service(
        session,
        booking_id=booking_id,
        actor_id=user.id,
        is_admin=_is_admin(user),
    )