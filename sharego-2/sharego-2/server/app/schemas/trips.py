from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TripCreate(BaseModel):
    origin_airport: str = Field(min_length=3, max_length=5)
    dest_airport: str = Field(min_length=3, max_length=5)
    date: datetime
    capacity_kg: float = Field(gt=0)
    fee_pkr: Optional[int] = Field(default=None, ge=0)
    flight_number: Optional[str] = Field(default=None, max_length=10)
    airline: Optional[str] = Field(default=None, max_length=50)


class TripRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    origin_airport: str
    dest_airport: str
    date: datetime
    capacity_kg: float
    fee_pkr: Optional[int]
    flight_number: Optional[str]
    airline: Optional[str]
    status: str = "pending_review"
    reject_reason: Optional[str] = None
    created_at: datetime
    traveler_name: Optional[str] = None
    traveler_rating: Optional[float] = None
