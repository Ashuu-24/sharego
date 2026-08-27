from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class WalletTransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    delta: float
    balance_after: float
    reason: str
    ref_id: str | None
    created_at: datetime


class WalletResponse(BaseModel):
    balance: float
    currency: str = "PKR"
    transactions: list[WalletTransactionRead]
    total_transactions: int


class WalletTopUpRequest(BaseModel):
    user_id: int
    amount: float
    reason: str = "admin_topup"


class UserTopUpRequest(BaseModel):
    amount: float
