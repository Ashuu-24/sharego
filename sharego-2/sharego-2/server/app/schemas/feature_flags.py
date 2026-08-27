from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class FeatureFlagCreate(BaseModel):
    key: str
    value: str
    cohort: Optional[str] = None


class FeatureFlagUpdate(BaseModel):
    value: Optional[str] = None
    cohort: Optional[str] = None


class FeatureFlagRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    key: str
    value: str
    cohort: Optional[str] = None
    updated_at: datetime
