from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class BookingCreate(BaseModel):
    trip_id: int
    request_id: int
    amount: float = Field(ge=0)
    currency: str = Field(default="PKR", min_length=3, max_length=3)


class BookingVerifyPickup(BaseModel):
    otp: str = Field(min_length=4, max_length=12)
    gps_lat: float
    gps_lng: float
    photo_paths: list[str] = Field(default_factory=list, min_length=1)
    seal_id: str | None = None


class BookingVerifyDelivery(BaseModel):
    otp: str = Field(min_length=4, max_length=12)
    gps_lat: float
    gps_lng: float
    photo_paths: list[str] = Field(default_factory=list, min_length=1)
    seal_id: str | None = None


class BookingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    trip_id: int
    request_id: int
    buyer_id: int
    traveler_id: int
    status: str
    waybill: str | None
    escrow_status: str | None
    amount: float | None
    currency: str | None
    seal_id: str | None
    pickup_verified_at: datetime | None
    delivery_verified_at: datetime | None
    created_at: datetime
    updated_at: datetime
    pickup_otp_dev: str | None = None
    delivery_otp_dev: str | None = None
    buyer_name: str | None = None
    product_name: str | None = None

