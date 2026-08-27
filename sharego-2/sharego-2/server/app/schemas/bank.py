from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class BankAccountCreate(BaseModel):
    bank_name: str
    account_title: str
    account_number: str


class BankAccountRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    bank_name: str
    account_title: str
    account_number: str
    is_default: bool
    created_at: datetime


class WithdrawRequest(BaseModel):
    bank_account_id: int
    amount: float