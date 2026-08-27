from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Query, Response, status
from sqlmodel import Session

from app.api.deps import get_current_user_dep, get_session_dep, enforce_kyc_approved
from app.domain.requests.service import (
    create_request as create_request_service,
    delete_request as delete_request_service,
    get_request as get_request_service,
    list_requests as list_requests_service,
    update_request as update_request_service,
)
from app.models import User
from app.schemas.requests import RequestCreate, RequestRead, RequestUpdate

router = APIRouter(prefix="/requests", tags=["requests"])


@router.get("", response_model=list[RequestRead])
async def list_requests(
    dest_city: str | None = None,
    date_window_start: datetime | None = Query(default=None, alias="dateWindowStart"),
    date_window_end: datetime | None = Query(default=None, alias="dateWindowEnd"),
    min_price: float | None = Query(default=None, ge=0),
    max_price: float | None = Query(default=None, ge=0),
    session: Session = Depends(get_session_dep),
):
    return list_requests_service(
        session,
        dest_city=dest_city,
        date_window=(date_window_start, date_window_end),
        min_price=min_price,
        max_price=max_price,
    )


@router.post("", response_model=RequestRead, status_code=status.HTTP_201_CREATED)
async def create_request(
    payload: RequestCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    enforce_kyc_approved(user)
    return create_request_service(session, user_id=user.id, data=payload)


@router.get("/{request_id}", response_model=RequestRead)
async def get_request(request_id: int, session: Session = Depends(get_session_dep)):
    return get_request_service(session, request_id=request_id)


@router.patch("/{request_id}", response_model=RequestRead)
async def update_request(
    request_id: int,
    payload: RequestUpdate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    return update_request_service(
        session,
        request_id=request_id,
        owner_id=user.id,
        data=payload,
    )


@router.delete("/{request_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def delete_request(
    request_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    delete_request_service(session, request_id=request_id, owner_id=user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
