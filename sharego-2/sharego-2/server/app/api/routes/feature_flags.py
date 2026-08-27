from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import get_current_user_dep, get_request_id_dep, get_session_dep
from app.core.audit import write_audit_log
from app.models import FeatureFlag, User
from app.schemas.feature_flags import FeatureFlagCreate, FeatureFlagRead, FeatureFlagUpdate

router = APIRouter(prefix="/admin/flags", tags=["feature-flags"])


def _admin_only(user: User) -> None:
    if "admin" not in user.roles and "ops" not in user.roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")


@router.get("", response_model=list[FeatureFlagRead])
async def list_flags(
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
):
    _admin_only(user)
    return session.exec(select(FeatureFlag)).all()


@router.post("", response_model=FeatureFlagRead, status_code=status.HTTP_201_CREATED)
async def create_flag(
    payload: FeatureFlagCreate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    existing = session.exec(select(FeatureFlag).where(FeatureFlag.key == payload.key)).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Flag '{payload.key}' already exists")
    flag = FeatureFlag(key=payload.key, value=payload.value, cohort=payload.cohort)
    session.add(flag)
    session.commit()
    session.refresh(flag)
    write_audit_log(
        session,
        actor=str(user.id),
        action="flag_created",
        entity=f"feature_flag:{flag.id}",
        request_id=request_id,
        after={"key": flag.key, "value": flag.value},
    )
    return flag


@router.patch("/{flag_id}", response_model=FeatureFlagRead)
async def update_flag(
    flag_id: int,
    payload: FeatureFlagUpdate,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    flag = session.get(FeatureFlag, flag_id)
    if not flag:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Flag not found")
    before = {"value": flag.value, "cohort": flag.cohort}
    if payload.value is not None:
        flag.value = payload.value
    if payload.cohort is not None:
        flag.cohort = payload.cohort
    flag.updated_at = datetime.utcnow()
    session.add(flag)
    session.commit()
    session.refresh(flag)
    write_audit_log(
        session,
        actor=str(user.id),
        action="flag_updated",
        entity=f"feature_flag:{flag.id}",
        request_id=request_id,
        before=before,
        after={"value": flag.value, "cohort": flag.cohort},
    )
    return flag


@router.delete("/{flag_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_flag(
    flag_id: int,
    session: Session = Depends(get_session_dep),
    user: User = Depends(get_current_user_dep),
    request_id: str = Depends(get_request_id_dep),
):
    _admin_only(user)
    flag = session.get(FeatureFlag, flag_id)
    if not flag:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Flag not found")
    write_audit_log(
        session,
        actor=str(user.id),
        action="flag_deleted",
        entity=f"feature_flag:{flag.id}",
        request_id=request_id,
        before={"key": flag.key, "value": flag.value},
    )
    session.delete(flag)
    session.commit()
