from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlmodel import Session, select, col
from app.api.deps import get_current_user_dep, get_session_dep
from app.models import Notification, User

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
async def list_notifications(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """Logged-in user ki saari notifications — newest pehle."""
    notifs = session.exec(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(col(Notification.created_at).desc())
        .limit(100)
    ).all()
    return notifs


@router.get("/unread-count")
async def unread_count(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """Badge ke liye — sirf unread count return karta hai."""
    notifs = session.exec(
        select(Notification).where(
            Notification.user_id == user.id,
            Notification.is_read == False,
        )
    ).all()
    return {"count": len(notifs)}


@router.post("/{notif_id}/read")
async def mark_read(
    notif_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """Ek notification read mark karo."""
    notif = session.get(Notification, notif_id)
    if notif and notif.user_id == user.id:
        notif.is_read = True
        session.add(notif)
        session.commit()
    return {"ok": True}


@router.post("/read-all")
async def mark_all_read(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    """Saari notifications ek baar mein read mark karo."""
    notifs = session.exec(
        select(Notification).where(
            Notification.user_id == user.id,
            Notification.is_read == False,
        )
    ).all()
    for n in notifs:
        n.is_read = True
        session.add(n)
    session.commit()
    return {"marked": len(notifs)}