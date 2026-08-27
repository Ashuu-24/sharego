from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException, status
from sqlmodel import Session, select

from app.models import RequestItem, Trip, User

_DESTINATION_ALIASES = {
    "LHE": ("LHE", "LAHORE"),
    "KHI": ("KHI", "KARACHI"),
    "ISB": ("ISB", "ISLAMABAD"),
}

_CITY_TO_AIRPORT = {
    "LAHORE": "LHE",
    "KARACHI": "KHI",
    "ISLAMABAD": "ISB",
}


def _normalize(text: str) -> str:
    return " ".join(text.strip().upper().split())


def _destination_match(dest_airport: str, dest_city: str) -> bool:
    airport_norm = _normalize(dest_airport)
    city_norm = _normalize(dest_city)
    if not airport_norm or not city_norm:
        return False
    if airport_norm == city_norm:
        return True

    if city_norm in _CITY_TO_AIRPORT:
        return _CITY_TO_AIRPORT[city_norm] == airport_norm

    if airport_norm in _DESTINATION_ALIASES:
        aliases = _DESTINATION_ALIASES[airport_norm]
        return any(alias in city_norm for alias in aliases)

    return airport_norm in city_norm or city_norm in airport_norm


def _window_midpoint(start: datetime, end: datetime) -> datetime:
    return start + (end - start) / 2


def suggest_for_request(session: Session, request_id: int) -> list[Trip]:
    request_item = session.get(RequestItem, request_id)
    if not request_item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")

    candidate_query = select(Trip).where(
        Trip.capacity_kg >= request_item.weight_kg,
        Trip.date >= request_item.window_start,
        Trip.date <= request_item.window_end,
    )
    candidates = [
        trip
        for trip in session.exec(candidate_query).all()
        if _destination_match(trip.dest_airport, request_item.dest_city)
    ]
    if not candidates:
        return []

    user_ids = {trip.user_id for trip in candidates}
    users = session.exec(select(User).where(User.id.in_(user_ids))).all()
    rating_by_user = {user.id: user.rating_avg for user in users}
    midpoint = _window_midpoint(request_item.window_start, request_item.window_end)

    return sorted(
        candidates,
        key=lambda trip: (
            abs((trip.date - midpoint).total_seconds()),
            -(rating_by_user.get(trip.user_id, 0.0)),
        ),
    )


def suggest_for_trip(session: Session, trip_id: int) -> list[RequestItem]:
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")

    candidate_query = select(RequestItem).where(
        RequestItem.weight_kg <= trip.capacity_kg,
        RequestItem.window_start <= trip.date,
        RequestItem.window_end >= trip.date,
    )
    candidates = [
        item
        for item in session.exec(candidate_query).all()
        if _destination_match(trip.dest_airport, item.dest_city)
    ]

    return sorted(
        candidates,
        key=lambda item: abs((trip.date - _window_midpoint(item.window_start, item.window_end)).total_seconds()),
    )
