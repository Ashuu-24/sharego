from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException, status
from sqlmodel import Session, select

from app.models import RequestItem
from app.schemas.requests import RequestCreate, RequestUpdate


def _validate_window(window_start: datetime, window_end: datetime) -> None:
    if window_end < window_start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="window_end must be greater than or equal to window_start",
        )


def _validate_price_range(min_price: float | None, max_price: float | None) -> None:
    if (
        min_price is not None
        and max_price is not None
        and max_price < min_price
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="max_price must be greater than or equal to min_price",
        )


def _validate_owner(owner_id: int, target_owner_id: int) -> None:
    if owner_id != target_owner_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not owner")


def _build_filtered_query(
    *,
    dest_city: str | None = None,
    date_window: tuple[datetime | None, datetime | None] | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
):
    query = select(RequestItem)
    if dest_city:
        query = query.where(RequestItem.dest_city.ilike(f"%{dest_city.strip()}%"))

    if date_window:
        date_from, date_to = date_window
        if date_from:
            query = query.where(RequestItem.window_end >= date_from)
        if date_to:
            query = query.where(RequestItem.window_start <= date_to)

    if min_price is not None:
        query = query.where(RequestItem.target_price >= min_price)
    if max_price is not None:
        query = query.where(RequestItem.target_price <= max_price)
    return query.order_by(RequestItem.created_at.desc())


def create_request(session: Session, *, user_id: int, data: RequestCreate) -> RequestItem:
    _validate_window(data.window_start, data.window_end)
    item = RequestItem(user_id=user_id, **data.model_dump())
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


def list_requests(
    session: Session,
    *,
    dest_city: str | None = None,
    date_window: tuple[datetime | None, datetime | None] | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
) -> list[RequestItem]:
    _validate_price_range(min_price, max_price)
    if date_window:
        start, end = date_window
        if start and end and end < start:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date window")
    query = _build_filtered_query(
        dest_city=dest_city,
        date_window=date_window,
        min_price=min_price,
        max_price=max_price,
    )
    return list(session.exec(query).all())


def get_request(
    session: Session,
    *,
    request_id: int,
    owner_only: bool = False,
    owner_id: int | None = None,
) -> RequestItem:
    item = session.get(RequestItem, request_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    if owner_only:
        if owner_id is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="owner_id is required")
        _validate_owner(owner_id, item.user_id)
    return item


def update_request(
    session: Session,
    *,
    request_id: int,
    owner_id: int,
    data: RequestUpdate,
) -> RequestItem:
    item = get_request(session, request_id=request_id)
    _validate_owner(owner_id, item.user_id)

    updates = data.model_dump(exclude_unset=True)
    window_start = updates.get("window_start", item.window_start)
    window_end = updates.get("window_end", item.window_end)
    _validate_window(window_start, window_end)

    for field, value in updates.items():
        setattr(item, field, value)

    session.add(item)
    session.commit()
    session.refresh(item)
    return item


def delete_request(session: Session, *, request_id: int, owner_id: int) -> None:
    item = get_request(session, request_id=request_id)
    _validate_owner(owner_id, item.user_id)
    session.delete(item)
    session.commit()
