from __future__ import annotations

import json
from datetime import datetime
from secrets import randbelow

from fastapi import HTTPException, status
from passlib.context import CryptContext
from sqlmodel import Session

from app.core.audit import write_audit_log
from app.core.config import get_settings
from app.models import Booking, BookingStatus, HandoverEvent, RequestItem, Trip

_settings = get_settings()
_pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=max(4, _settings.otp_bcrypt_rounds),
)


def _utcnow() -> datetime:
    return datetime.utcnow()


def _get_booking_bundle(session: Session, booking_id: int) -> tuple[Booking, Trip, RequestItem]:
    booking = session.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    trip = session.get(Trip, booking.trip_id)
    if not trip:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    request = session.get(RequestItem, booking.request_id)
    if not request:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    return booking, trip, request


def _hash_code(code: str) -> str:
    return _pwd_context.hash(code)


def _verify_code(code: str, code_hash: str) -> bool:
    return _pwd_context.verify(code, code_hash)


def _generate_code() -> str:
    return f"{randbelow(900000) + 100000:06d}"


def generate_codes(session: Session, *, booking_id: int) -> dict[str, str]:
    booking, _trip, _request = _get_booking_bundle(session, booking_id)
    pickup_code = _generate_code()
    delivery_code = _generate_code()
    booking.pickup_code_hash = _hash_code(pickup_code)
    booking.delivery_code_hash = _hash_code(delivery_code)
    booking.updated_at = _utcnow()
    session.add(booking)
    session.commit()
    return {"pickup_code": pickup_code, "delivery_code": delivery_code}


def verify_pickup(
    session: Session,
    *,
    booking_id: int,
    traveler_id: int,
    otp: str,
    gps_lat: float,
    gps_lng: float,
    photo_paths: list[str],
    seal_id: str | None,
    request_id: str | None = None,
) -> Booking:
    booking, trip, _request = _get_booking_bundle(session, booking_id)
    if trip.user_id != traveler_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only traveler can verify pickup")
    if booking.status != BookingStatus.ACCEPTED.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal booking transition", "from": booking.status, "to": BookingStatus.PICKUP_OK.value},
        )
    if not booking.pickup_code_hash:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Pickup OTP already consumed or missing")
    if not _verify_code(otp, booking.pickup_code_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid pickup OTP")
    if not photo_paths:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="At least one pickup photo is required")

    ts = _utcnow()
    booking.status = BookingStatus.PICKUP_OK.value
    booking.pickup_code_hash = None
    booking.updated_at = ts
    if seal_id:
        booking.seal_id = seal_id
    session.add(booking)
    event = HandoverEvent(
        booking_id=booking.id,
        type=BookingStatus.PICKUP_OK.value,
        gps_lat=gps_lat,
        gps_lng=gps_lng,
        photos_paths=json.dumps(photo_paths),
        seal_id=seal_id,
        ts=ts,
    )
    session.add(event)
    session.commit()
    session.refresh(booking)
    write_audit_log(
        session,
        actor=str(traveler_id),
        action="BOOKING_PICKUP_VERIFIED",
        entity=f"booking:{booking.id}",
        request_id=request_id,
        after={"status": booking.status, "seal_id": booking.seal_id},
    )
    return booking


def verify_delivery(
    session: Session,
    *,
    booking_id: int,
    buyer_id: int,
    otp: str,
    gps_lat: float,
    gps_lng: float,
    photo_paths: list[str],
    seal_id: str | None,
    request_id: str | None = None,
) -> Booking:
    booking, _trip, request = _get_booking_bundle(session, booking_id)
    if request.user_id != buyer_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only buyer can verify delivery")
    if booking.status != BookingStatus.PICKUP_OK.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal booking transition", "from": booking.status, "to": BookingStatus.DELIVERY_OK.value},
        )
    if not booking.delivery_code_hash:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Delivery OTP already consumed or missing")
    if not _verify_code(otp, booking.delivery_code_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid delivery OTP")
    if not photo_paths:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="At least one delivery photo is required")
    if booking.seal_id and not seal_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Seal ID is required for delivery")
    if booking.seal_id and seal_id != booking.seal_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Seal ID mismatch")

    ts = _utcnow()
    booking.status = BookingStatus.DELIVERY_OK.value
    booking.delivery_code_hash = None
    booking.updated_at = ts
    session.add(booking)
    event = HandoverEvent(
        booking_id=booking.id,
        type=BookingStatus.DELIVERY_OK.value,
        gps_lat=gps_lat,
        gps_lng=gps_lng,
        photos_paths=json.dumps(photo_paths),
        seal_id=seal_id,
        ts=ts,
    )
    session.add(event)
    session.commit()
    session.refresh(booking)
    write_audit_log(
        session,
        actor=str(buyer_id),
        action="BOOKING_DELIVERY_VERIFIED",
        entity=f"booking:{booking.id}",
        request_id=request_id,
        after={"status": booking.status, "seal_id": booking.seal_id},
    )
    return booking

