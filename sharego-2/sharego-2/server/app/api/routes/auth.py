import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, EmailStr
from sqlmodel import Session, select

from app.api.deps import get_request_id_dep, get_settings_dep, get_session_dep
from app.core.audit import write_audit_log
from app.core.config import Settings
from app.core.limits import limiter
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User

from app.services.email import send_otp_email
from app.services.otp import otp_service

router = APIRouter(prefix="/auth", tags=["auth"])


class OTPRequest(BaseModel):
    email: EmailStr
    phone: str | None = None


class OTPVerify(BaseModel):
    email: EmailStr
    otp: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    roles: list[str] = ["user"]
    expires_in_minutes: int


def _ensure_password_strength(password: str, min_length: int) -> None:
    if len(password) < min_length:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Password must be at least {min_length} characters",
        )
    if not any(ch.isalpha() for ch in password) or not any(ch.isdigit() for ch in password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must include at least one letter and one number",
        )


@router.post("/register", response_model=dict)
@limiter.limit("3/minute")
async def request_otp(
    request: Request,
    payload: OTPRequest,
    settings: Settings = Depends(get_settings_dep),
    session: Session = Depends(get_session_dep),
    request_id: str = Depends(get_request_id_dep),
):
    otp_service.configure_rounds(settings.otp_bcrypt_rounds)
    client_ip = request.client.host if request.client else "unknown"
    throttled = otp_service.is_throttled(
        session,
        email=str(payload.email),
        ip_address=client_ip,
        window_seconds=settings.otp_throttle_window_seconds,
        max_attempts=settings.otp_throttle_limit,
    )
    if throttled:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="OTP throttle exceeded")

    code = otp_service.issue(
        session=session,
        email=payload.email,
        ttl_seconds=settings.otp_ttl_seconds,
        max_attempts=settings.otp_max_attempts,
        dev_mode=settings.env == "dev",
    )
    # ensure user exists with role user
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if not user:
        new_user = User(email=payload.email, phone=payload.phone or "", roles_csv="user")
        session.add(new_user)
        session.commit()
        session.refresh(new_user)
    # Send OTP via email (skipped in dev mode where otp_dev is returned instead)
    if settings.env != "dev":
        send_otp_email(
            to_email=str(payload.email),
            otp_code=code,
            sender=settings.otp_sender_email,
            smtp_host=settings.otp_smtp_host,
            smtp_port=settings.otp_smtp_port,
            smtp_user=settings.otp_smtp_user,
            smtp_pass=settings.otp_smtp_pass,
        )

    response = {"message": "OTP issued"}
    if settings.env == "dev":
        response["otp_dev"] = code

    write_audit_log(
        session,
        actor=str(payload.email),
        action="AUTH_OTP_REQUESTED",
        entity="auth",
        request_id=request_id,
        after={"email": str(payload.email)},
    )
    return response


@router.post("/forgot", response_model=dict)
@limiter.limit("3/minute")
async def forgot_password(
    request: Request,
    payload: OTPRequest,
    settings: Settings = Depends(get_settings_dep),
    session: Session = Depends(get_session_dep),
    request_id: str = Depends(get_request_id_dep),
):
    """Re-issue OTP for an existing account (forgot-password / re-login flow)."""
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if not user:
        # Don't reveal whether the account exists.
        return {"message": "If the account exists, an OTP has been sent."}

    otp_service.configure_rounds(settings.otp_bcrypt_rounds)
    client_ip = request.client.host if request.client else "unknown"
    throttled = otp_service.is_throttled(
        session,
        email=str(payload.email),
        ip_address=client_ip,
        window_seconds=settings.otp_throttle_window_seconds,
        max_attempts=settings.otp_throttle_limit,
    )
    if throttled:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="OTP throttle exceeded")

    code = otp_service.issue(
        session=session,
        email=payload.email,
        ttl_seconds=settings.otp_ttl_seconds,
        max_attempts=settings.otp_max_attempts,
        dev_mode=settings.env == "dev",
    )
    # Send OTP via email
    if settings.env != "dev":
        send_otp_email(
            to_email=str(payload.email),
            otp_code=code,
            sender=settings.otp_sender_email,
            smtp_host=settings.otp_smtp_host,
            smtp_port=settings.otp_smtp_port,
            smtp_user=settings.otp_smtp_user,
            smtp_pass=settings.otp_smtp_pass,
        )

    response: dict = {"message": "If the account exists, an OTP has been sent."}
    if settings.env == "dev":
        response["otp_dev"] = code

    write_audit_log(
        session,
        actor=str(payload.email),
        action="AUTH_FORGOT_OTP_REQUESTED",
        entity="auth",
        request_id=request_id,
        after={"email": str(payload.email)},
    )
    return response


@router.post("/verify-otp", response_model=TokenResponse)
@limiter.limit("3/minute")
async def verify_otp(
    request: Request,
    payload: OTPVerify,
    settings: Settings = Depends(get_settings_dep),
    session: Session = Depends(get_session_dep),
    request_id: str = Depends(get_request_id_dep),
):
    otp_service.configure_rounds(settings.otp_bcrypt_rounds)
    valid = otp_service.verify(session=session, email=payload.email, otp=payload.otp)
    if not valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")
    user = session.exec(select(User).where(User.email == payload.email)).first()
    roles = user.roles if user else ["user"]
    token = create_access_token(
        subject=payload.email,
        settings=settings,
        extra_claims={"roles": roles},
    )
    write_audit_log(
        session,
        actor=str(payload.email),
        action="AUTH_OTP_VERIFIED",
        entity="auth",
        request_id=request_id,
        after={"roles": roles, "client_ip": request.client.host if request.client else "unknown"},
    )
    return TokenResponse(access_token=token, roles=roles, expires_in_minutes=settings.jwt_expire_minutes)


class PasswordRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    phone: str | None = None


class PasswordLoginRequest(BaseModel):
    email: EmailStr
    password: str


@router.post("/register-password", response_model=TokenResponse)
@limiter.limit("5/minute")
async def register_with_password(
    request: Request,
    payload: PasswordRegisterRequest,
    settings: Settings = Depends(get_settings_dep),
    session: Session = Depends(get_session_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _ensure_password_strength(payload.password, settings.password_min_length)
    existing = session.exec(select(User).where(User.email == payload.email)).first()
    if existing and existing.password_hash:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )
    if existing:
        existing.password_hash = hash_password(payload.password)
        if payload.phone:
            existing.phone = payload.phone
        session.add(existing)
        session.commit()
        session.refresh(existing)
        user = existing
    else:
        user = User(
            email=payload.email,
            phone=payload.phone or "",
            password_hash=hash_password(payload.password),
            roles_csv="user",
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    roles = user.roles
    token = create_access_token(
        subject=str(payload.email),
        settings=settings,
        extra_claims={"roles": roles},
    )
    write_audit_log(
        session,
        actor=str(payload.email),
        action="AUTH_PASSWORD_REGISTER",
        entity="auth",
        request_id=request_id,
        after={"email": str(payload.email)},
    )
    return TokenResponse(access_token=token, roles=roles, expires_in_minutes=settings.jwt_expire_minutes)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
async def login_with_password(
    request: Request,
    payload: PasswordLoginRequest,
    settings: Settings = Depends(get_settings_dep),
    session: Session = Depends(get_session_dep),
    request_id: str = Depends(get_request_id_dep),
):
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    roles = user.roles
    token = create_access_token(
        subject=str(payload.email),
        settings=settings,
        extra_claims={"roles": roles},
    )
    write_audit_log(
        session,
        actor=str(payload.email),
        action="AUTH_PASSWORD_LOGIN",
        entity="auth",
        request_id=request_id,
        after={"email": str(payload.email)},
    )
    return TokenResponse(access_token=token, roles=roles, expires_in_minutes=settings.jwt_expire_minutes)


class GoogleAuthRequest(BaseModel):
    id_token: str


@router.post("/google", response_model=TokenResponse)
@limiter.limit("10/minute")
async def google_sign_in(
    request: Request,
    payload: GoogleAuthRequest,
    settings: Settings = Depends(get_settings_dep),
    session: Session = Depends(get_session_dep),
    request_id: str = Depends(get_request_id_dep),
):
    """Authenticate via Google ID token. Creates user if not exists."""
    # Verify the ID token with Google
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": payload.id_token},
        )
    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google ID token",
        )
    token_info = resp.json()

    # Validate audience matches our client ID (if configured)
    token_aud = token_info.get("aud")
    if settings.google_client_id and token_aud != settings.google_client_id:
        detail = "Token audience mismatch"
        if settings.env == "dev":
            detail += f" (got={token_aud}, expected={settings.google_client_id})"
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
        )

    email = token_info.get("email")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google token missing email",
        )

    # Create user if not exists
    is_new = False
    user = session.exec(select(User).where(User.email == email)).first()
    if not user:
        is_new = True
        user = User(email=email, phone="", roles_csv="user")
        session.add(user)
        session.commit()
        session.refresh(user)

    roles = user.roles if user else ["user"]
    token = create_access_token(
        subject=email,
        settings=settings,
        extra_claims={"roles": roles},
    )

    write_audit_log(
        session,
        actor=email,
        action="AUTH_GOOGLE_SIGN_IN",
        entity="auth",
        request_id=request_id,
        after={"email": email, "new_user": is_new},
    )
    return TokenResponse(access_token=token, roles=roles, expires_in_minutes=settings.jwt_expire_minutes)
