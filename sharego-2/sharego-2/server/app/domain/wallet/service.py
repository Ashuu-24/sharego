from __future__ import annotations

from fastapi import HTTPException, status
from sqlmodel import Session, select

from app.domain.escrow.service import deduct_wallet
from app.models import BankAccount

from app.domain.ledger_reasons import LedgerReason


def list_bank_accounts(session: Session, *, user_id: int) -> list[BankAccount]:
    return session.exec(
        select(BankAccount)
        .where(BankAccount.user_id == user_id)
        .order_by(BankAccount.created_at.desc())
    ).all()


def add_bank_account(
    session: Session,
    *,
    user_id: int,
    bank_name: str,
    account_title: str,
    account_number: str,
) -> BankAccount:
    existing = list_bank_accounts(session, user_id=user_id)
    account = BankAccount(
        user_id=user_id,
        bank_name=bank_name,
        account_title=account_title,
        account_number=account_number,
        is_default=len(existing) == 0,
    )
    session.add(account)
    session.commit()
    session.refresh(account)
    return account


def delete_bank_account(session: Session, *, user_id: int, account_id: int) -> None:
    account = session.get(BankAccount, account_id)
    if not account or account.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank account not found")
    session.delete(account)
    session.commit()


def withdraw_to_bank(
    session: Session,
    *,
    user_id: int,
    bank_account_id: int,
    amount: float,
    ref_id: str,
):
    account = session.get(BankAccount, bank_account_id)
    if not account or account.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank account not found")
    if amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Amount must be positive")

    return deduct_wallet(
        session,
        user_id=user_id,
        amount=amount,
        reason=LedgerReason.BANK_WITHDRAWAL,
        ref_id=f"bank:{account.id}:{ref_id}",
    )