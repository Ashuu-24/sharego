import time
from datetime import datetime
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.api.deps import get_session_dep, get_current_user_dep, enforce_kyc_approved
from app.core.config import get_settings
from app.models import Trip, User
from app.schemas import TripCreate, TripRead


from app.services.notifications import push 


router = APIRouter(prefix="/trips", tags=["trips"])

# ── In-memory cache for AviationStack (10-min TTL) ─────────────────

_flight_cache: dict[str, tuple[float, dict]] = {}
_CACHE_TTL = 600  # 10 minutes


@router.post("", response_model=TripRead, status_code=status.HTTP_201_CREATED)
async def create_trip(
    payload: TripCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    enforce_kyc_approved(user)
    trip = Trip(
        user_id=user.id,
        origin_airport=payload.origin_airport,
        dest_airport=payload.dest_airport,
        date=payload.date,
        capacity_kg=payload.capacity_kg,
        fee_pkr=payload.fee_pkr,
        flight_number=payload.flight_number,
        airline=payload.airline,
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    push(
        session,
        user_id=user.id,
        type="trip",
        title="Trip Created ✈️",
        body=f"Your trip #{trip.id} has been created and is now visible for bookings.",
        route=f"/trips/{trip.id}",
    )
     
    
    trip_data = TripRead.model_validate(trip)
    trip_data.traveler_name = user.name or user.email
    trip_data.traveler_rating = user.rating_avg
    return trip_data


@router.get("", response_model=list[TripRead])
async def list_trips(
    session: Session = Depends(get_session_dep),
    user: User | None = Depends(get_current_user_dep),
    origin: Optional[str] = Query(None, description="Filter by origin airport code"),
    dest: Optional[str] = Query(None, description="Filter by destination airport code"),
    date_from: Optional[datetime] = Query(None, description="Trips on or after this date"),
    date_to: Optional[datetime] = Query(None, description="Trips on or before this date"),
    min_capacity: Optional[float] = Query(None, ge=0, description="Minimum available capacity in kg"),
    mine: bool = Query(False, description="Show only my trips (all statuses)"),
):
    stmt = select(Trip)

    if mine and user:
        # Owner sees all their trips regardless of status.
        stmt = stmt.where(Trip.user_id == user.id)
    else:
        # Public listing: only approved trips.
        stmt = stmt.where(Trip.status == "approved")

    if origin:
        stmt = stmt.where(Trip.origin_airport == origin.upper())
    if dest:
        stmt = stmt.where(Trip.dest_airport == dest.upper())
    if date_from:
        stmt = stmt.where(Trip.date >= date_from)
    if date_to:
        stmt = stmt.where(Trip.date <= date_to)
    if min_capacity is not None:
        stmt = stmt.where(Trip.capacity_kg >= min_capacity)

    stmt = stmt.order_by(Trip.date.desc())
    trips = session.exec(stmt).all()

    # Enrich with traveler info
    user_cache: dict[int, User | None] = {}
    result = []
    for trip in trips:
        trip_data = TripRead.model_validate(trip)
        if trip.user_id not in user_cache:
            user_cache[trip.user_id] = session.get(User, trip.user_id)
        owner = user_cache.get(trip.user_id)
        if owner:
            trip_data.traveler_name = owner.name or owner.email
            trip_data.traveler_rating = owner.rating_avg
        result.append(trip_data)
    return result


@router.get("/{trip_id}", response_model=TripRead)
async def get_trip(
    trip_id: int,
    session: Session = Depends(get_session_dep),
):
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    trip_data = TripRead.model_validate(trip)
    owner = session.get(User, trip.user_id)
    if owner:
        trip_data.traveler_name = owner.name or owner.email
        trip_data.traveler_rating = owner.rating_avg
    return trip_data


async def fetch_flight_status(flight_number: str, api_key: str) -> dict:
    """Shared helper: fetch flight status from AviationStack with caching."""
    flight_iata = flight_number.replace(" ", "").upper()

    # Check cache first.
    now = time.time()
    if flight_iata in _flight_cache:
        cached_at, cached_data = _flight_cache[flight_iata]
        if now - cached_at < _CACHE_TTL:
            return cached_data

    # Call AviationStack API.
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                "https://api.aviationstack.com/v1/flights",
                params={
                    "access_key": api_key,
                    "flight_iata": flight_iata,
                },
            )
            resp.raise_for_status()
            raw = resp.json()
    except Exception:
        raise HTTPException(status_code=502, detail="Failed to reach flight tracking service")

    flights = raw.get("data", [])
    if not flights:
        result = {
            "flight_number": flight_iata,
            "flight_status": "not_found",
            "departure": None,
            "arrival": None,
            "live": None,
        }
        _flight_cache[flight_iata] = (now, result)
        return result

    f = flights[0]
    result = {
        "flight_number": flight_iata,
        "flight_status": f.get("flight_status", "unknown"),
        "departure": {
            "airport": f.get("departure", {}).get("airport"),
            "iata": f.get("departure", {}).get("iata"),
            "scheduled": f.get("departure", {}).get("scheduled"),
            "estimated": f.get("departure", {}).get("estimated"),
            "actual": f.get("departure", {}).get("actual"),
            "delay": f.get("departure", {}).get("delay"),
        },
        "arrival": {
            "airport": f.get("arrival", {}).get("airport"),
            "iata": f.get("arrival", {}).get("iata"),
            "scheduled": f.get("arrival", {}).get("scheduled"),
            "estimated": f.get("arrival", {}).get("estimated"),
            "actual": f.get("arrival", {}).get("actual"),
            "delay": f.get("arrival", {}).get("delay"),
        },
        "live": f.get("live"),
    }

    _flight_cache[flight_iata] = (now, result)
    return result


@router.get("/{trip_id}/flight-status")
async def get_flight_status(
    trip_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """Get real-time flight status via AviationStack API."""
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if not trip.flight_number:
        raise HTTPException(status_code=400, detail="No flight number set for this trip")

    settings = get_settings()
    if not settings.aviationstack_api_key:
        raise HTTPException(status_code=503, detail="Flight tracking not configured")

    return await fetch_flight_status(trip.flight_number, settings.aviationstack_api_key)
