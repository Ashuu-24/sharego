from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session

from app.api.deps import get_current_user_dep, get_session_dep
from app.domain.matching.service import suggest_for_request, suggest_for_trip
from app.models import User
from app.schemas.requests import RequestRead
from app.schemas.trips import TripRead

router = APIRouter(prefix="/matching", tags=["matching"])


@router.get("/suggest")
async def get_suggestions(
    request_id: int | None = Query(default=None, alias="requestId"),
    trip_id: int | None = Query(default=None, alias="tripId"),
    session: Session = Depends(get_session_dep),
    _user: User = Depends(get_current_user_dep),
):
    if (request_id is None and trip_id is None) or (request_id is not None and trip_id is not None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide exactly one query param: requestId or tripId",
        )

    if request_id is not None:
        trips = suggest_for_request(session, request_id)
        return {
            "requestId": request_id,
            "tripId": None,
            "trips": [TripRead.model_validate(trip).model_dump() for trip in trips],
            "requests": [],
        }

    requests = suggest_for_trip(session, trip_id)
    return {
        "requestId": None,
        "tripId": trip_id,
        "trips": [],
        "requests": [RequestRead.model_validate(item).model_dump() for item in requests],
    }
