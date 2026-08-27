from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class EscrowRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    booking_id: int
    amount: float
    currency: str
    status: str
    provider: str
    created_at: datetime


class WalletEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    delta: float
    balance_after: float
    reason: str
    ref_id: str | None
    created_at: datetime

