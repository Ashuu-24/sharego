from __future__ import annotations
from sqlmodel import Session
from app.models import Notification


def push(
    session: Session,
    *,
    user_id: int,
    type: str,
    title: str,
    body: str,
    route: str | None = None,
) -> Notification:
    notif = Notification(
        user_id=user_id,
        type=type,
        title=title,
        body=body,
        route=route,
    )
    session.add(notif)
    session.commit()
    return notif