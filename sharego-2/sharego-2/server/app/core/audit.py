from __future__ import annotations

from typing import Any

from sqlmodel import Session

from app.models import AuditLog


def write_audit_log(
    session: Session,
    *,
    actor: str | None,
    action: str,
    entity: str,
    request_id: str | None = None,
    before: Any = None,
    after: Any = None,
) -> None:
    entry = AuditLog(
        actor=actor,
        action=action,
        entity=entity,
        request_id=request_id,
        before=None if before is None else str(before),
        after=None if after is None else str(after),
    )
    session.add(entry)
    session.commit()
