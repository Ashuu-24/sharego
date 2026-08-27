from __future__ import annotations

from datetime import datetime, timedelta, timezone
import secrets

from passlib.context import CryptContext
from sqlmodel import Session, select
from sqlalchemy import delete

from app.models import OTPEntry, OTPThrottle


class OTPService:
    def __init__(self) -> None:
        # Adjustable per-env by setting rounds through update_policy at runtime.
        self._pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)

    def configure_rounds(self, rounds: int) -> None:
        self._pwd_context = CryptContext(
            schemes=["bcrypt"],
            deprecated="auto",
            bcrypt__rounds=max(4, rounds),
        )

    def _hash(self, code: str) -> str:
        return self._pwd_context.hash(code)

    def _verify(self, code: str, hashed_code: str) -> bool:
        return self._pwd_context.verify(code, hashed_code)

    def is_throttled(
        self,
        session: Session,
        *,
        email: str,
        ip_address: str,
        window_seconds: int,
        max_attempts: int,
    ) -> bool:
        now = datetime.now(timezone.utc)
        row = session.exec(
            select(OTPThrottle).where(
                OTPThrottle.email == email,
                OTPThrottle.ip_address == ip_address,
            )
        ).first()

        if row is None:
            session.add(
                OTPThrottle(
                    email=email,
                    ip_address=ip_address,
                    window_start=now,
                    count=1,
                    updated_at=now,
                )
            )
            session.commit()
            return False

        window_start = row.window_start
        if window_start.tzinfo is None:
            window_start = window_start.replace(tzinfo=timezone.utc)

        if window_start + timedelta(seconds=window_seconds) < now:
            row.window_start = now
            row.count = 1
            row.updated_at = now
            session.add(row)
            session.commit()
            return False

        row.count += 1
        row.updated_at = now
        session.add(row)
        session.commit()
        return row.count > max_attempts

    def issue(self, session: Session, email: str, ttl_seconds: int, max_attempts: int, dev_mode: bool = False) -> str:
        code = "123456" if dev_mode else f"{secrets.randbelow(900000) + 100000:06d}"
        hashed = self._hash(code)
        expires_at = datetime.now(timezone.utc) + timedelta(seconds=ttl_seconds)

        session.exec(delete(OTPEntry).where(OTPEntry.email == email))
        entry = OTPEntry(
            email=email,
            hashed_code=hashed,
            expires_at=expires_at,
            attempts=0,
            max_attempts=max_attempts,
        )
        session.add(entry)
        session.commit()
        return code

    def verify(self, session: Session, email: str, otp: str) -> bool:
        entry = session.exec(select(OTPEntry).where(OTPEntry.email == email)).first()
        if not entry:
            return False
        if entry.attempts >= entry.max_attempts:
            return False

        expires_at = entry.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            return False

        entry.attempts += 1
        session.add(entry)
        session.commit()

        if not self._verify(otp, entry.hashed_code):
            return False

        session.delete(entry)
        session.commit()
        return True


otp_service = OTPService()
