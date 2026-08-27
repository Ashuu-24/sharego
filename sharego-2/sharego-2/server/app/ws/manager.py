from __future__ import annotations

import asyncio
import logging
from collections import defaultdict

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[user_id].add(websocket)

    async def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            sockets = self._connections.get(user_id)
            if not sockets:
                return
            sockets.discard(websocket)
            if not sockets:
                self._connections.pop(user_id, None)

    async def send_to_user(self, user_id: int, data: dict) -> None:
        async with self._lock:
            sockets = list(self._connections.get(user_id, ()))
        stale: list[WebSocket] = []
        for ws in sockets:
            try:
                await ws.send_json(data)
            except Exception:
                logger.debug("dropping stale chat websocket for user_id=%s", user_id)
                stale.append(ws)
        for ws in stale:
            await self.disconnect(user_id, ws)

    async def broadcast_message(self, payload: dict, sender_id: int, receiver_id: int) -> None:
        event = {"type": "message", "payload": payload}
        await self.send_to_user(sender_id, event)
        if receiver_id != sender_id:
            await self.send_to_user(receiver_id, event)


chat_manager = ConnectionManager()
