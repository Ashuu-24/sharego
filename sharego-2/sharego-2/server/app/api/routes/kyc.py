import re
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.api.deps import get_session_dep, get_current_user_dep, get_settings_dep
from app.core.config import Settings
from app.models import KYCProfile, Trip, User

router = APIRouter(prefix="/kyc", tags=["kyc"])

_CNIC_RE = re.compile(r"^\d{5}-?\d{7}-?\d$")
_PASSPORT_RE = re.compile(r"^[A-Za-z0-9]{6,9}$")


class KYCSubmit(BaseModel):
    doc_type: str  # "cnic" or "passport"
    doc_url: str
    selfie_url: str | None = None
    passport_url: str | None = None  # Required for travelers (users with trips).
    doc_number: str | None = None  # Optional document number for validation.

    @field_validator("doc_type")
    @classmethod
    def validate_doc_type(cls, v: str) -> str:
        v = v.lower().strip()
        if v not in ("cnic", "passport"):
            raise ValueError("doc_type must be 'cnic' or 'passport'")
        return v

    @field_validator("doc_number")
    @classmethod
    def validate_doc_number(cls, v: str | None, info) -> str | None:
        if v is None:
            return v
        doc_type = info.data.get("doc_type", "")
        if doc_type == "cnic":
            cleaned = v.replace("-", "")
            if not cleaned.isdigit() or len(cleaned) != 13:
                raise ValueError("CNIC must be 13 digits (XXXXX-XXXXXXX-X)")
            if not _CNIC_RE.match(v) and len(v) != 13:
                raise ValueError("CNIC format: XXXXX-XXXXXXX-X or 13 digits")
        elif doc_type == "passport":
            if not _PASSPORT_RE.match(v):
                raise ValueError("Passport number must be 6-9 alphanumeric characters")
        return v


class KYCStatus(BaseModel):
    status: str
    doc_type: str | None = None
    doc_url: str | None = None
    selfie_url: str | None = None
    passport_url: str | None = None
    reject_reason: str | None = None


@router.post("/submit", response_model=KYCStatus, status_code=status.HTTP_201_CREATED)
async def submit_kyc(
    payload: KYCSubmit,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    settings: Settings = Depends(get_settings_dep),
):
    # K2: Validate media file existence.
    media_root = Path(settings.media_root)
    if payload.doc_url and not (media_root / payload.doc_url).exists():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Document file not found: {payload.doc_url}. Upload via /media/upload first.",
        )
    if payload.selfie_url and not (media_root / payload.selfie_url).exists():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Selfie file not found: {payload.selfie_url}. Upload via /media/upload first.",
        )
    if payload.passport_url and not (media_root / payload.passport_url).exists():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Passport file not found: {payload.passport_url}. Upload via /media/upload first.",
        )

    # Travelers (users with trips) must upload a passport photo.
    has_trips = session.exec(select(Trip).where(Trip.user_id == user.id).limit(1)).first()
    if has_trips and not payload.passport_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Travelers must upload a passport photo for KYC verification.",
        )

    existing = session.exec(select(KYCProfile).where(KYCProfile.user_id == user.id)).first()
    if existing:
        # K5: Block resubmission if already approved.
        if existing.status == "approved":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="KYC already approved. No resubmission needed.",
            )
        existing.doc_type = payload.doc_type
        existing.doc_url = payload.doc_url
        existing.selfie_url = payload.selfie_url
        existing.passport_url = payload.passport_url
        existing.status = "pending"
        existing.reject_reason = None  # Clear previous rejection reason.
        existing.updated_at = datetime.utcnow()
        session.add(existing)
        session.commit()
        session.refresh(existing)
        profile = existing
    else:
        profile = KYCProfile(
            user_id=user.id,
            status="pending",
            doc_type=payload.doc_type,
            doc_url=payload.doc_url,
            selfie_url=payload.selfie_url,
            passport_url=payload.passport_url,
        )
        session.add(profile)
        session.commit()
        session.refresh(profile)
    return KYCStatus(
        status=profile.status,
        doc_type=profile.doc_type,
        doc_url=profile.doc_url,
        selfie_url=profile.selfie_url,
        passport_url=profile.passport_url,
        reject_reason=profile.reject_reason,
    )


@router.get("/status", response_model=KYCStatus)
async def get_status(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    profile = session.exec(select(KYCProfile).where(KYCProfile.user_id == user.id)).first()
    if not profile:
        # K4: Graceful response for first-time users instead of 404.
        return KYCStatus(status="not_submitted")
    return KYCStatus(
        status=profile.status,
        doc_type=profile.doc_type,
        doc_url=profile.doc_url,
        selfie_url=profile.selfie_url,
        passport_url=profile.passport_url,
        reject_reason=profile.reject_reason,
    )
