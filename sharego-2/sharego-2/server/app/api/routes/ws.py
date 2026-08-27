from __future__ import annotations

import logging

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from pydantic import ValidationError

from app.api.deps import user_from_access_token
from app.core.config import get_settings
from app.db import get_session
from app.schemas.messages import MessageCreate
from app.services.messages import persist_and_broadcast
from app.ws.manager import chat_manager

logger = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])


def _token_from_websocket(websocket: WebSocket, token: str | None) -> str | None:
    if token:
        return token
    header = websocket.headers.get("authorization") or websocket.headers.get("Authorization")
    if header and header.lower().startswith("bearer "):
        return header.split(" ", 1)[1].strip()
    return None


@router.websocket("/ws/chat")
async def chat_websocket(
    websocket: WebSocket,
    token: str | None = Query(default=None),
):
    raw_token = _token_from_websocket(websocket, token)
    if not raw_token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    settings = get_settings()
    with get_session() as session:
        user = user_from_access_token(raw_token, session, settings)
        if not user or user.id is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
        user_id = user.id

    await chat_manager.connect(user_id, websocket)
    try:
        await websocket.send_json({"type": "ready", "user_id": user_id})
        while True:
            data = await websocket.receive_json()
            event_type = data.get("type") if isinstance(data, dict) else None
            if event_type == "ping":
                await websocket.send_json({"type": "pong"})
                continue
            if event_type != "send":
                await websocket.send_json({"type": "error", "detail": "Unknown event"})
                continue
            try:
                payload = MessageCreate(
                    receiver_id=int(data["receiver_id"]),
                    content=str(data.get("content") or ""),
                    booking_id=data.get("booking_id"),
                    listing_id=data.get("listing_id"),
                )
            except (KeyError, TypeError, ValueError, ValidationError):
                await websocket.send_json({"type": "error", "detail": "Invalid send payload"})
                continue
            try:
                with get_session() as session:
                    sender = user_from_access_token(raw_token, session, settings)
                    if not sender:
                        await websocket.send_json({"type": "error", "detail": "Invalid token"})
                        continue
                    await persist_and_broadcast(session, sender, payload)
            except Exception as exc:
                detail = getattr(exc, "detail", None) or "Could not send message"
                await websocket.send_json({"type": "error", "detail": str(detail)})
    except WebSocketDisconnect:
        logger.debug("chat websocket disconnected user_id=%s", user_id)
    except Exception:
        logger.exception("chat websocket error user_id=%s", user_id)
    finally:
        await chat_manager.disconnect(user_id, websocket)
