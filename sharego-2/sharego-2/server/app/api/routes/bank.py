from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session

from app.api.deps import get_current_user_dep, get_session_dep
from app.domain.wallet.service import (
    add_bank_account,
    delete_bank_account,
    list_bank_accounts,
)
from app.models import User
from app.schemas.bank import BankAccountCreate, BankAccountRead

router = APIRouter(prefix="/users/me/bank-accounts", tags=["bank"])


@router.get("", response_model=list[BankAccountRead])
async def get_bank_accounts(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    return list_bank_accounts(session, user_id=user.id)


@router.post("", response_model=BankAccountRead)
async def create_bank_account(
    payload: BankAccountCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    return add_bank_account(
        session,
        user_id=user.id,
        bank_name=payload.bank_name,
        account_title=payload.account_title,
        account_number=payload.account_number,
    )


@router.delete("/{account_id}")
async def remove_bank_account(
    account_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    delete_bank_account(session, user_id=user.id, account_id=account_id)
    return {"message": "Bank account removed"}