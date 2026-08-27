from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class MessageCreate(BaseModel):
    receiver_id: int
    content: str
    booking_id: Optional[int] = None
    listing_id: Optional[int] = None


class MessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_id: int
    receiver_id: int
    content: str
    booking_id: Optional[int] = None
    listing_id: Optional[int] = None
    created_at: datetime
    read_at: Optional[datetime] = None


class ThreadSummary(BaseModel):
    peer_id: int
    last_message: str
    last_ts: datetime
    unread_count: int
