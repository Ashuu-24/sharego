from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

ALLOWED_UPDATE_TYPES = {"picked_up", "at_airport", "in_transit", "arrived", "custom"}


class BookingUpdateCreate(BaseModel):
    update_type: str = Field(min_length=1, max_length=50)
    note: str | None = Field(default=None, max_length=500)


class BookingUpdateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    booking_id: int
    user_id: int
    update_type: str
    note: str | None
    created_at: datetime
    user_name: str | None = None
