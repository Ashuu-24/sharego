from __future__ import annotations

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt, JWTError
from sqlmodel import Session, select

from app.core.config import get_settings, Settings
from app.db import get_session
from app.models import User


def get_settings_dep() -> Settings:
    return get_settings()


def get_session_dep():
    with get_session() as session:
        yield session


bearer_scheme = HTTPBearer(auto_error=False)


def decode_token_payload(token: str, settings: Settings) -> dict | None:
    try:
        decode_kwargs = {"algorithms": [settings.jwt_alg]}
        if settings.jwt_issuer:
            decode_kwargs["issuer"] = settings.jwt_issuer
        if settings.jwt_audience:
            decode_kwargs["audience"] = settings.jwt_audience
        return jwt.decode(token, settings.jwt_secret, **decode_kwargs)
    except JWTError:
        return None


def user_from_access_token(token: str, session: Session, settings: Settings) -> User | None:
    payload = decode_token_payload(token, settings)
    if not payload:
        return None
    sub = payload.get("sub")
    if not sub:
        return None
    return session.exec(select(User).where(User.email == sub)).first()


def get_current_user_dep(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing auth")
    user = user_from_access_token(credentials.credentials, session, settings)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return user


def get_request_id_dep(request: Request) -> str:
    return getattr(request.state, "request_id", "")


def enforce_owner(user: User, owner_user_id: int) -> None:
    if user.id != owner_user_id and "admin" not in user.roles and "ops" not in user.roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not owner")


def enforce_kyc_approved(user: User) -> None:
    """Block action if user's KYC is not approved (admin/ops bypass)."""
    if "admin" in user.roles or "ops" in user.roles:
        return
    if user.kyc_status != "approved":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="KYC verification required. Please submit and get your KYC approved before proceeding.",
        )
