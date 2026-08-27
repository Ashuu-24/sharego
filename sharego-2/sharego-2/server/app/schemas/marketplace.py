from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

MARKETPLACE_DISCLAIMER = (
    "Marketplace transactions are peer-to-peer with private offers only (no auctions). "
    "Flyro does not provide escrow, delivery, courier, or payment services for Marketplace deals. "
    "Parties must arrange logistics."
)

ListingStatus = Literal["active", "paused", "sold", "removed"]


class ListingCreate(BaseModel):
    title: str = Field(min_length=3, max_length=80)
    description: str = Field(min_length=1, max_length=2000)
    photos_paths: list[str] = Field(default_factory=list)
    category: str | None = None
    condition: str | None = None
    location_text: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    ask_price: float = Field(ge=0)
    currency: str = Field(default="PKR", min_length=3, max_length=3)
    contact_pref: str | None = None


class ListingUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=80)
    description: str | None = Field(default=None, min_length=1, max_length=2000)
    photos_paths: list[str] | None = None
    category: str | None = None
    condition: str | None = None
    location_text: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    ask_price: float | None = Field(default=None, ge=0)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    contact_pref: str | None = None
    status: ListingStatus | None = None


class ListingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    seller_id: int
    title: str
    description: str
    photos_paths: list[str] = Field(default_factory=list)
    category: str | None
    condition: str | None
    location_text: str | None
    latitude: float | None
    longitude: float | None
    ask_price: float
    currency: str
    contact_pref: str | None
    status: str
    created_at: datetime
    updated_at: datetime
    marketplace_disclaimer: str = MARKETPLACE_DISCLAIMER


class OfferCreate(BaseModel):
    amount: float = Field(ge=0)
    currency: str = Field(default="PKR", min_length=3, max_length=3)
    message: str | None = None


class OfferAction(BaseModel):
    amount: float | None = Field(default=None, ge=0)
    message: str | None = None


class OfferRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    listing_id: int
    from_user_id: int
    amount: float
    currency: str
    message: str | None
    status: str
    ts: datetime
    marketplace_disclaimer: str = MARKETPLACE_DISCLAIMER


class MeetupCreate(BaseModel):
    listing_id: int
    place_text: str = Field(min_length=3, max_length=300)
    scheduled_ts: datetime


class MeetupConfirm(BaseModel):
    otp: str = Field(min_length=4, max_length=12)


class MeetupRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    listing_id: int
    buyer_id: int
    seller_id: int
    place_text: str
    scheduled_ts: datetime
    confirmed_ts: datetime | None
    note: str | None
    marketplace_disclaimer: str = MARKETPLACE_DISCLAIMER
    otp_dev: str | None = None


class MarkSoldPayload(BaseModel):
    offer_id: int | None = None
    note: str | None = None
