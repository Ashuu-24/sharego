from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreate(BaseModel):
    target_type: Literal["booking", "market"]
    target_id: int
    reviewee_id: int
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=1000)


class ReviewRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    reviewer_id: int
    reviewee_id: int
    target_type: str
    target_id: int
    rating: int
    comment: str | None
    ts: datetime
    reviewer_name: str | None = None
