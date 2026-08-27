from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import get_current_user_dep, get_request_id_dep, get_session_dep
from app.core.audit import write_audit_log
from app.models import KYCProfile, User
from app.schemas.kyc import KYCProfileRead, KYCRejectPayload



from app.services.notifications import push   


router = APIRouter(prefix="/admin/kyc", tags=["admin-kyc"])


# ── helpers ──────────────────────────────────────────────────────────


def _admin_only(user: User) -> None:
    if "admin" not in user.roles and "ops" not in user.roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )


def _get_profile(session: Session, user_id: int) -> KYCProfile:
    profile = session.exec(
        select(KYCProfile).where(KYCProfile.user_id == user_id)
    ).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No KYC profile found for user {user_id}",
        )
    return profile


def _set_kyc_status(
    session: Session,
    *,
    user_id: int,
    new_status: str,
    admin_id: int,
    request_id: str,
    reject_reason: str | None = None,
) -> KYCProfile:
    profile = _get_profile(session, user_id)
    old_status = profile.status

    profile.status = new_status
    profile.reject_reason = reject_reason
    profile.updated_at = datetime.utcnow()
    session.add(profile)

    # Also mirror the status on the User row for quick access.
    user = session.get(User, user_id)
    if user:
        user.kyc_status = new_status
        session.add(user)

    session.commit()
    session.refresh(profile)

    write_audit_log(
        session,
        actor=str(admin_id),
        action=f"kyc_{new_status}",
        entity=f"kyc_profile:{profile.id}",
        request_id=request_id,
        before={"status": old_status},
        after={"status": new_status},
    )

    return profile


# ── routes ───────────────────────────────────────────────────────────


@router.get("/pending", response_model=list[KYCProfileRead])
async def list_pending_kyc(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    _admin_only(user)
    profiles = session.exec(
        select(KYCProfile).where(KYCProfile.status == "pending")
    ).all()
    return profiles


@router.post("/{user_id}/approve", response_model=KYCProfileRead)
async def approve_kyc(
    user_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    profile = _set_kyc_status(
        session,
        user_id=user_id,
        new_status="approved",
        admin_id=user.id,
        request_id=request_id,
    )
    push(
        session,
        user_id=user_id,
        type="kyc",
        title="KYC Approved ",
        body=f"Your KYC profile has been approved. You can now use all features",
        route="/profile",
    )
    return profile


@router.post("/{user_id}/reject", response_model=KYCProfileRead)
async def reject_kyc(
    user_id: int,
    payload: KYCRejectPayload | None = None,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    reason = payload.reason if payload else None
    profile = _set_kyc_status(
        session,
        user_id=user_id,
        new_status="rejected",
        admin_id=user.id,
        request_id=request_id,
        reject_reason=reason,
    )
    push(
        session,
        user_id=user_id,
        type="kyc",
        title="KYC Rejected ❌",
        body=f"Your KYC was rejected. Reason: {reason or 'Not provided'}",
        route="/kyc",
    )
    return profile
