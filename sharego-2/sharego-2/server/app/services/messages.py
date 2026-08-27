from __future__ import annotations

from fastapi import HTTPException, status
from sqlmodel import Session

from app.models import Message, User
from app.schemas.messages import MessageCreate, MessageRead
from app.services.notifications import push
from app.ws.manager import chat_manager


def persist_message(session: Session, sender: User, payload: MessageCreate) -> Message:
    if payload.receiver_id == sender.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot message yourself")
    content = (payload.content or "").strip()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty")
    receiver = session.get(User, payload.receiver_id)
    if not receiver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receiver not found")

    msg = Message(
        sender_id=sender.id,
        receiver_id=payload.receiver_id,
        content=content,
        booking_id=payload.booking_id,
        listing_id=payload.listing_id,
    )
    session.add(msg)
    session.commit()
    session.refresh(msg)

    push(
        session,
        user_id=payload.receiver_id,
        type="message",
        title=f"New message from {sender.name or sender.email}",
        body=content[:80],
        route=f"/chat/{sender.id}",
    )
    return msg


def message_payload(msg: Message) -> dict:
    return MessageRead.model_validate(msg).model_dump(mode="json")


async def persist_and_broadcast(session: Session, sender: User, payload: MessageCreate) -> Message:
    msg = persist_message(session, sender, payload)
    await chat_manager.broadcast_message(
        message_payload(msg),
        sender_id=msg.sender_id,
        receiver_id=msg.receiver_id,
    )
    return msg
