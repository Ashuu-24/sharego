from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from sqlmodel import Field, SQLModel


class BookingStatus(str, Enum):
    REQUESTED = "REQUESTED"
    HOLD_PLACED = "HOLD_PLACED"
    ACCEPTED = "ACCEPTED"
    PICKUP_OK = "PICKUP_OK"
    DELIVERY_OK = "DELIVERY_OK"
    RELEASED = "RELEASED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class OfferStatus(str, Enum):
    SENT = "SENT"
    COUNTERED = "COUNTERED"
    ACCEPTED = "ACCEPTED"
    DECLINED = "DECLINED"
    WITHDRAWN = "WITHDRAWN"


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True, unique=True)
    phone: Optional[str] = None
    name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    password_hash: Optional[str] = None
    roles_csv: str = Field(default="user")
    kyc_status: str = Field(default="pending")
    rating_avg: float = Field(default=0.0)
    created_at: datetime = Field(default_factory=datetime.utcnow)

    @property
    def roles(self) -> list[str]:
        return [r for r in self.roles_csv.split(",") if r]


class OTPEntry(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True)
    hashed_code: str
    expires_at: datetime
    attempts: int = 0
    max_attempts: int = 3
    created_at: datetime = Field(default_factory=datetime.utcnow)


class OTPThrottle(SQLModel, table=True):
    __tablename__ = "otp_throttles"

    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True)
    ip_address: str = Field(index=True)
    window_start: datetime = Field(default_factory=datetime.utcnow)
    count: int = Field(default=0)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Trip(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    origin_airport: str = Field(index=True)
    dest_airport: str = Field(index=True)
    date: datetime
    capacity_kg: float
    fee_pkr: int | None = None
    flight_number: str | None = None
    airline: str | None = None
    status: str = Field(default="pending_review", index=True)
    reject_reason: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class KYCProfile(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    status: str = Field(default="pending")
    doc_type: str | None = None
    doc_url: str | None = None
    selfie_url: str | None = None
    passport_url: str | None = None
    reject_reason: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class RequestItem(SQLModel, table=True):
    __tablename__ = "requests"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    product_name: str
    specs_json: str | None = None
    target_price: float = 0
    dest_city: str
    weight_kg: float
    window_start: datetime
    window_end: datetime
    declaration_path: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Booking(SQLModel, table=True):
    __tablename__ = "bookings"

    id: Optional[int] = Field(default=None, primary_key=True)
    trip_id: int = Field(index=True)
    request_id: int = Field(index=True)
    status: str = Field(default=BookingStatus.REQUESTED.value, index=True)
    waybill: str | None = None
    pickup_code_hash: str | None = None
    delivery_code_hash: str | None = None
    seal_id: str | None = None
    receipt_path: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class EscrowTx(SQLModel, table=True):
    __tablename__ = "escrow_tx"

    id: Optional[int] = Field(default=None, primary_key=True)
    booking_id: int = Field(index=True)
    amount: float
    currency: str = Field(default="PKR")
    status: str = Field(default="hold", index=True)
    provider: str = Field(default="virtual")
    created_at: datetime = Field(default_factory=datetime.utcnow)


class WalletEntry(SQLModel, table=True):
    __tablename__ = "wallet_entries"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    delta: float
    balance_after: float
    reason: str
    ref_id: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class HandoverEvent(SQLModel, table=True):
    __tablename__ = "handover_events"

    id: Optional[int] = Field(default=None, primary_key=True)
    booking_id: int = Field(index=True)
    type: str
    gps_lat: float | None = None
    gps_lng: float | None = None
    photos_paths: str | None = None
    seal_id: str | None = None
    ts: datetime = Field(default_factory=datetime.utcnow)


class MarketListing(SQLModel, table=True):
    __tablename__ = "market_listings"

    id: Optional[int] = Field(default=None, primary_key=True)
    seller_id: int = Field(index=True)
    title: str = Field(index=True)
    description: str
    photos_paths: str | None = None
    category: str | None = Field(default=None, index=True)
    condition: str | None = None
    location_text: str | None = Field(default=None, index=True)
    latitude: float | None = None
    longitude: float | None = None
    ask_price: float = Field(index=True)
    currency: str = Field(default="PKR")
    contact_pref: str | None = None
    status: str = Field(default="active", index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class MarketOffer(SQLModel, table=True):
    __tablename__ = "market_offers"

    id: Optional[int] = Field(default=None, primary_key=True)
    listing_id: int = Field(index=True)
    from_user_id: int = Field(index=True)
    amount: float
    currency: str = Field(default="PKR")
    message: str | None = None
    status: str = Field(default=OfferStatus.SENT.value, index=True)
    ts: datetime = Field(default_factory=datetime.utcnow)


class MarketMeetup(SQLModel, table=True):
    __tablename__ = "market_meetups"

    id: Optional[int] = Field(default=None, primary_key=True)
    listing_id: int = Field(index=True)
    buyer_id: int = Field(index=True)
    seller_id: int = Field(index=True)
    place_text: str
    scheduled_ts: datetime
    otp_hash: str | None = None
    confirmed_ts: datetime | None = None
    note: str | None = None


class Review(SQLModel, table=True):
    __tablename__ = "reviews"

    id: Optional[int] = Field(default=None, primary_key=True)
    reviewer_id: int = Field(index=True)
    reviewee_id: int = Field(index=True)
    target_type: str = Field(index=True)
    target_id: int = Field(index=True)
    rating: int
    comment: str | None = None
    ts: datetime = Field(default_factory=datetime.utcnow)


class Dispute(SQLModel, table=True):
    __tablename__ = "disputes"

    id: Optional[int] = Field(default=None, primary_key=True)
    target_type: str = Field(index=True)
    target_id: int = Field(index=True)
    opened_by: int = Field(index=True)
    reason: str
    status: str = Field(default="open", index=True)
    resolution: str | None = None
    ts_open: datetime = Field(default_factory=datetime.utcnow)
    ts_close: datetime | None = None


class DisputeEvidence(SQLModel, table=True):
    __tablename__ = "dispute_evidence"

    id: Optional[int] = Field(default=None, primary_key=True)
    dispute_id: int = Field(index=True)
    by_user: int = Field(index=True)
    file_path: str
    note: str | None = None
    ts: datetime = Field(default_factory=datetime.utcnow)


class FeatureFlag(SQLModel, table=True):
    __tablename__ = "feature_flags"

    id: Optional[int] = Field(default=None, primary_key=True)
    key: str = Field(index=True, unique=True)
    value: str
    cohort: str | None = None
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Message(SQLModel, table=True):
    __tablename__ = "messages"

    id: Optional[int] = Field(default=None, primary_key=True)
    sender_id: int = Field(index=True)
    receiver_id: int = Field(index=True)
    content: str
    booking_id: int | None = Field(default=None, index=True)
    listing_id: int | None = Field(default=None, index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    read_at: datetime | None = None


class BookingUpdate(SQLModel, table=True):
    __tablename__ = "booking_updates"

    id: Optional[int] = Field(default=None, primary_key=True)
    booking_id: int = Field(index=True)
    user_id: int = Field(index=True)
    update_type: str = Field(index=True)
    note: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class AuditLog(SQLModel, table=True):
    __tablename__ = "audit_logs"

    id: Optional[int] = Field(default=None, primary_key=True)
    actor: str | None = Field(default=None, index=True)
    action: str = Field(index=True)
    entity: str = Field(index=True)
    before: str | None = None
    after: str | None = None
    request_id: str | None = Field(default=None, index=True)
    ts: datetime = Field(default_factory=datetime.utcnow, index=True)
    
class Notification(SQLModel, table=True):
    __tablename__ = "notifications"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    type: str = Field(index=True)
    title: str
    body: str
    is_read: bool = Field(default=False)
    route: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)
    
class BankAccount(SQLModel, table=True):
    __tablename__ = "bank_accounts"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    bank_name: str
    account_title: str
    account_number: str          # store masked/last-4 only in real apps
    is_default: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
