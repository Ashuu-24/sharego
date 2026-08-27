from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class RequestCreate(BaseModel):
    product_name: str = Field(min_length=3, max_length=120)
    specs_json: Optional[str] = None
    target_price: float = Field(ge=0)
    dest_city: str = Field(min_length=2, max_length=80)
    weight_kg: float = Field(gt=0)
    window_start: datetime
    window_end: datetime
    declaration_path: Optional[str] = None


class RequestRead(BaseModel):
    id: int
    user_id: int
    product_name: str
    specs_json: Optional[str]
    target_price: float
    dest_city: str
    weight_kg: float
    window_start: datetime
    window_end: datetime
    declaration_path: Optional[str]
    created_at: datetime


class BookingCreate(BaseModel):
    trip_id: int
    request_id: int
    amount: float = Field(gt=0)
    currency: str = Field(default="PKR", min_length=3, max_length=3)


class BookingRead(BaseModel):
    id: int
    trip_id: int
    request_id: int
    status: str
    created_at: datetime
    updated_at: datetime


class MarketListingCreate(BaseModel):
    title: str = Field(min_length=3, max_length=80)
    description: str = Field(min_length=1, max_length=2000)
    photos_paths: Optional[str] = None
    category: Optional[str] = None
    condition: Optional[str] = None
    location_text: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    ask_price: float = Field(ge=0)
    currency: str = Field(default="PKR", min_length=3, max_length=3)
    contact_pref: Optional[str] = None


class MarketListingRead(BaseModel):
    id: int
    seller_id: int
    title: str
    description: str
    photos_paths: Optional[str]
    category: Optional[str]
    condition: Optional[str]
    location_text: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    ask_price: float
    currency: str
    contact_pref: Optional[str]
    status: str
    created_at: datetime
    updated_at: datetime
