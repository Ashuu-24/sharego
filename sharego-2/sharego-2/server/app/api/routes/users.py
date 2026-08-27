from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlmodel import Session, select

from app.api.deps import get_current_user_dep, get_session_dep
from app.domain.escrow.service import get_balance, _add_wallet_entry
from app.models import User, WalletEntry
from app.schemas import UserRead, UserUpdate
from app.schemas.users import UserPublicRead
from app.schemas.wallet import UserTopUpRequest, WalletResponse, WalletTransactionRead

from app.domain.wallet.service import withdraw_to_bank   # the new file you're creating
from app.schemas.bank import WithdrawRequest       

from app.domain.ledger_reasons import LedgerReason

router = APIRouter(prefix="/users", tags=["users"])


def _user_to_read(user: User) -> UserRead:
    return UserRead(
        id=user.id,
        email=user.email,
        phone=user.phone,
        name=user.name,
        city=user.city,
        country=user.country,
        roles=user.roles,
        kyc_status=user.kyc_status,
        rating_avg=user.rating_avg,
        created_at=user.created_at,
    )


def _user_to_public_read(user: User) -> UserPublicRead:
    return UserPublicRead(
        id=user.id,
        name=user.name,
        city=user.city,
        country=user.country,
        kyc_status=user.kyc_status,
        rating_avg=user.rating_avg,
        created_at=user.created_at,
    )


@router.get("/me", response_model=UserRead)
async def get_me(user: User = Depends(get_current_user_dep)):
    return _user_to_read(user)


@router.patch("/me", response_model=UserRead)
async def update_me(
    payload: UserUpdate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(user, key, value)
    session.add(user)
    session.commit()
    session.refresh(user)
    return _user_to_read(user)


@router.get("/me/wallet", response_model=WalletResponse)
async def get_wallet(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    balance = get_balance(session, user.id)
    total = session.exec(
        select(func.count(WalletEntry.id)).where(WalletEntry.user_id == user.id)
    ).one()
    entries = session.exec(
        select(WalletEntry)
        .where(WalletEntry.user_id == user.id)
        .order_by(WalletEntry.created_at.desc())
        .offset(offset)
        .limit(limit)
    ).all()
    transactions = [
        WalletTransactionRead(
            id=e.id,
            delta=e.delta,
            balance_after=e.balance_after,
            reason=e.reason,
            ref_id=e.ref_id,
            created_at=e.created_at,
        )
        for e in entries
    ]
    return WalletResponse(
        balance=balance,
        currency="PKR",
        transactions=transactions,
        total_transactions=int(total),
    )


@router.post("/me/wallet/topup")
async def user_topup_wallet(
    payload: UserTopUpRequest,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    if payload.amount <= 0 or payload.amount > 500_000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Amount must be between 1 and 500,000",
        )
    _add_wallet_entry(
        session,
        user_id=user.id,
        delta=payload.amount,
        reason="LedgerReason.SELF_TOPUP,",
        ref_id=f"topup:user:{user.id}",
    )
    balance = get_balance(session, user.id)
    return {"message": "Top-up successful", "balance": balance}

@router.post("/me/wallet/withdraw")
async def user_withdraw_wallet(
    payload: WithdrawRequest,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    withdraw_to_bank(
        session,
        user_id=user.id,
        bank_account_id=payload.bank_account_id,
        amount=payload.amount,
        ref_id=f"user:{user.id}",
    )
    balance = get_balance(session, user.id)
    return {"message": "Withdrawal successful", "balance": balance}


@router.get("/{user_id}", response_model=UserPublicRead)
async def get_user(
    user_id: int,
    session: Session = Depends(get_session_dep),
    _actor: User = Depends(get_current_user_dep),
):
    user = session.exec(select(User).where(User.id == user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _user_to_public_read(user)

