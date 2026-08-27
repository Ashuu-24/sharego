from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserRead(BaseModel):
    id: int
    email: EmailStr
    phone: Optional[str] = None
    name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    roles: list[str]
    kyc_status: str
    rating_avg: float
    created_at: datetime


class UserPublicRead(BaseModel):
    id: int
    name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    kyc_status: str
    rating_avg: float
    created_at: datetime


class UserUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=100)
    phone: Optional[str] = Field(default=None, max_length=20)
    city: Optional[str] = Field(default=None, max_length=80)
    country: Optional[str] = Field(default=None, max_length=80)
