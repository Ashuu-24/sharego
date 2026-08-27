from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class KYCProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    status: str
    doc_type: Optional[str] = None
    doc_url: Optional[str] = None
    selfie_url: Optional[str] = None
    reject_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class KYCRejectPayload(BaseModel):
    reason: str | None = None
