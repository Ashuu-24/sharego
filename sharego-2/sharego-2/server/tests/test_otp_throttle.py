from datetime import datetime, timedelta, timezone

from sqlalchemy import delete
from sqlmodel import Session, SQLModel, select

from app.db import engine
from app.models import OTPThrottle
from app.services.otp import otp_service


def reset_table() -> None:
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        session.exec(delete(OTPThrottle))
        session.commit()


def test_otp_throttle_happy_path() -> None:
    reset_table()
    with Session(engine) as session:
        first = otp_service.is_throttled(
            session,
            email="throttle@example.com",
            ip_address="127.0.0.1",
            window_seconds=60,
            max_attempts=3,
        )
        second = otp_service.is_throttled(
            session,
            email="throttle@example.com",
            ip_address="127.0.0.1",
            window_seconds=60,
            max_attempts=3,
        )
    assert first is False
    assert second is False


def test_otp_throttle_unhappy_path() -> None:
    reset_table()
    with Session(engine) as session:
        for _ in range(3):
            assert (
                otp_service.is_throttled(
                    session,
                    email="blocked@example.com",
                    ip_address="127.0.0.1",
                    window_seconds=60,
                    max_attempts=3,
                )
                is False
            )
        blocked = otp_service.is_throttled(
            session,
            email="blocked@example.com",
            ip_address="127.0.0.1",
            window_seconds=60,
            max_attempts=3,
        )
        row = session.exec(select(OTPThrottle).where(OTPThrottle.email == "blocked@example.com")).first()
        row.window_start = datetime.now(timezone.utc) - timedelta(minutes=2)
        session.add(row)
        session.commit()
        after_window = otp_service.is_throttled(
            session,
            email="blocked@example.com",
            ip_address="127.0.0.1",
            window_seconds=60,
            max_attempts=3,
        )
    assert blocked is True
    assert after_window is False
