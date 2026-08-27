from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session

from app.api.deps import get_current_user_dep, get_request_id_dep, get_session_dep
from app.core.audit import write_audit_log
from app.domain.bookings.service import get_booking as get_booking_service
from app.domain.escrow.service import get_balance, refund, release
from app.models import User, WalletEntry
from app.schemas.bookings import BookingRead
from app.schemas.wallet import WalletTopUpRequest
from app.domain.ledger_reasons import LedgerReason

router = APIRouter(prefix="/admin/escrow", tags=["admin-escrow"])


def _admin_only(user: User) -> None:
    if "admin" not in user.roles and "ops" not in user.roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")


@router.post("/{booking_id}/release", response_model=BookingRead)
async def release_escrow(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    release(session, booking_id=booking_id, admin_id=user.id, request_id=request_id)
    return get_booking_service(session, booking_id=booking_id, actor_id=user.id, is_admin=True)


@router.post("/{booking_id}/refund", response_model=BookingRead)
async def refund_escrow(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    refund(session, booking_id=booking_id, admin_id=user.id, request_id=request_id)
    return get_booking_service(session, booking_id=booking_id, actor_id=user.id, is_admin=True)


@router.post("/wallet/topup")
async def topup_wallet(
    payload: WalletTopUpRequest,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    if payload.amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Amount must be positive")
    from app.domain.escrow.service import _current_balance, _add_wallet_entry
    entry = _add_wallet_entry(
        session,
        user_id=payload.user_id,
        delta=payload.amount,
        reason=payload.reason or LedgerReason.ADMIN_TOPUP,
        ref_id=f"admin:{user.id}",
    )
    write_audit_log(
        session,
        actor=str(user.id),
        action="WALLET_TOPUP",
        entity=f"user:{payload.user_id}",
        request_id=request_id,
        after={"amount": payload.amount, "reason": payload.reason, "balance_after": entry.balance_after},
    )
    return {"message": "Top-up successful", "balance": entry.balance_after}

