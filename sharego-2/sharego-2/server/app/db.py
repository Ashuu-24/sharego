from __future__ import annotations

import sqlite3
import time
from contextlib import contextmanager
from typing import Callable, Iterator, TypeVar

from sqlalchemy import event, inspect
from sqlalchemy.exc import OperationalError
from sqlmodel import Session, SQLModel, create_engine

from app.core.config import get_settings

T = TypeVar("T")

_settings = get_settings()
engine = create_engine(_settings.db_url, echo=False, future=True)
SQLModel.metadata.create_all(engine)

@event.listens_for(engine, "connect")
def _set_sqlite_pragmas(dbapi_connection, _connection_record) -> None:
    if isinstance(dbapi_connection, sqlite3.Connection):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL;")
        cursor.execute("PRAGMA foreign_keys=ON;")
        cursor.close()


def _is_locked_error(exc: BaseException) -> bool:
    return "database is locked" in str(exc).lower()


def run_with_retry(fn: Callable[[], T], *, max_retries: int | None = None) -> T:
    retries = max_retries if max_retries is not None else _settings.request_retry_attempts
    attempt = 0
    while True:
        try:
            return fn()
        except OperationalError as exc:
            if attempt >= retries or not _is_locked_error(exc):
                raise
            time.sleep(0.05 * (attempt + 1))
            attempt += 1


@contextmanager
def session_scope() -> Iterator[Session]:
    session = Session(engine)
    try:
        yield session
        run_with_retry(session.commit)
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@contextmanager
def get_session() -> Iterator[Session]:
    with Session(engine) as session:
        yield session


def ensure_schema_ready(*, strict: bool = True) -> None:
    inspector = inspect(engine)
    existing = set(inspector.get_table_names())
    expected = set(SQLModel.metadata.tables.keys())
    missing = sorted(expected - existing)
    if missing and strict:
        raise RuntimeError(
            "Database schema is not up to date. Missing tables: "
            f"{', '.join(missing)}. Run `alembic upgrade head`."
        )
