from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlmodel import Session, select

from app.core.audit import write_audit_log
from app.models import BankAccount, Booking, BookingStatus, EscrowTx, RequestItem, Trip, WalletEntry

from app.domain.ledger_reasons import LedgerReason

def _utcnow() -> datetime:
    return datetime.utcnow()


def _get_booking_bundle(session: Session, booking_id: int) -> tuple[Booking, Trip, RequestItem]:
    booking = session.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    trip = session.get(Trip, booking.trip_id)
    if not trip:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    request = session.get(RequestItem, booking.request_id)
    if not request:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    return booking, trip, request


def _get_escrow_or_404(session: Session, booking_id: int) -> EscrowTx:
    escrow = session.exec(
        select(EscrowTx)
        .where(EscrowTx.booking_id == booking_id)
        .order_by(EscrowTx.created_at.desc())
    ).first()
    if not escrow:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Escrow transaction not found")
    return escrow


def _current_balance(session: Session, user_id: int) -> float:
    value = session.exec(
        select(func.coalesce(func.sum(WalletEntry.delta), 0.0)).where(WalletEntry.user_id == user_id)
    ).one()
    return float(value or 0.0)


def _add_wallet_entry(
    session: Session,
    *,
    user_id: int,
    delta: float,
    reason: str,
    ref_id: str,
) -> WalletEntry:
    balance_after = _current_balance(session, user_id) + delta
    entry = WalletEntry(
        user_id=user_id,
        delta=delta,
        balance_after=balance_after,
        reason=reason,
        ref_id=ref_id,
    )
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return entry


DEMO_CREDIT_AMOUNT = 50_000.0
DEMO_CREDIT_CURRENCY = "PKR"


def get_balance(session: Session, user_id: int) -> float:
    return _current_balance(session, user_id)


def deduct_wallet(
    session: Session,
    *,
    user_id: int,
    amount: float,
    reason: str,
    ref_id: str,
) -> WalletEntry:
    if amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Deduction amount must be positive")
    balance = _current_balance(session, user_id)
    if balance < amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Insufficient wallet balance", "balance": balance, "required": amount},
        )
    return _add_wallet_entry(session, user_id=user_id, delta=-amount, reason=reason, ref_id=ref_id)


def credit_demo_balance(session: Session, *, user_id: int) -> WalletEntry | None:
    existing = session.exec(
        select(WalletEntry).where(WalletEntry.user_id == user_id, WalletEntry.reason == "demo_credit")
    ).first()
    if existing:
        return None
    return _add_wallet_entry(
        session,
        user_id=user_id,
        delta=DEMO_CREDIT_AMOUNT,
        reason=f"reason={LedgerReason.DEMO_CREDIT}",
        ref_id="welcome_bonus",
    )


def simulate_hold(session: Session, *, booking_id: int, amount: float, currency: str) -> EscrowTx:
    if amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Escrow amount must be greater than zero")

    _booking, _trip, _request = _get_booking_bundle(session, booking_id)
    existing = session.exec(
        select(EscrowTx).where(EscrowTx.booking_id == booking_id, EscrowTx.status == "hold")
    ).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Escrow hold already exists")

    tx = EscrowTx(
        booking_id=booking_id,
        amount=amount,
        currency=currency.upper(),
        status="hold",
        provider="virtual",
    )
    session.add(tx)
    session.commit()
    session.refresh(tx)
    return tx


def release(
    session: Session,
    *,
    booking_id: int,
    admin_id: int,
    request_id: str | None = None,
) -> Booking:
    booking, trip, _request = _get_booking_bundle(session, booking_id)
    escrow = _get_escrow_or_404(session, booking_id)
    if booking.status != BookingStatus.DELIVERY_OK.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Illegal booking transition", "from": booking.status, "to": BookingStatus.RELEASED.value},
        )
    if escrow.status != "hold":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Escrow is not in hold state")

    escrow.status = "released"
    booking.status = BookingStatus.RELEASED.value
    booking.updated_at = _utcnow()
    session.add(escrow)
    session.add(booking)
    session.commit()

    _add_wallet_entry(
        session,
        user_id=trip.user_id,
        delta=LedgerReason.ESCROW_RELEASE,
        reason="escrow_release",
        ref_id=f"booking:{booking.id}",
    )
    session.refresh(booking)
    write_audit_log(
        session,
        actor=str(admin_id),
        action="ESCROW_RELEASED",
        entity=f"booking:{booking.id}",
        request_id=request_id,
        after={"status": booking.status, "amount": escrow.amount, "currency": escrow.currency},
    )
    return booking


def refund(
    session: Session,
    *,
    booking_id: int,
    admin_id: int,
    request_id: str | None = None,
) -> Booking:
    booking, _trip, request = _get_booking_bundle(session, booking_id)
    escrow = _get_escrow_or_404(session, booking_id)
    if booking.status == BookingStatus.RELEASED.value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Released booking cannot be refunded")
    if escrow.status != "hold":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Escrow is not in hold state")

    escrow.status = "refunded"
    booking.status = BookingStatus.CANCELLED.value
    booking.updated_at = _utcnow()
    session.add(escrow)
    session.add(booking)
    session.commit()

    _add_wallet_entry(
        session,
        user_id=request.user_id,
        delta=escrow.amount,
        reason="LedgerReason.ESCROW_REFUND",
        ref_id=f"booking:{booking.id}",
    )
    session.refresh(booking)
    write_audit_log(
        session,
        actor=str(admin_id),
        action="ESCROW_REFUNDED",
        entity=f"booking:{booking.id}",
        request_id=request_id,
        after={"status": booking.status, "amount": escrow.amount, "currency": escrow.currency},
    )
    return booking



def withdraw_to_bank(session, *, user_id, bank_account_id, amount, ref_id):
    account = session.get(BankAccount, bank_account_id)
    if not account or account.user_id != user_id:
        raise HTTPException(404, "Bank account not found")
    # dummy: no real transfer call, just deduct + tag reason
    return deduct_wallet(
        session, user_id=user_id, amount=amount,
        reason="bank_withdrawal", ref_id=f"bank:{account.id}:{ref_id}",
    )
