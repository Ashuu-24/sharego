from fastapi import APIRouter, Depends

from app.api.deps import get_settings_dep
from app.core.config import Settings

router = APIRouter(tags=["ops"])


@router.get("/health")
async def health(settings: Settings = Depends(get_settings_dep)):
    return {
        "status": "ok",
        "env": settings.env,
        "timezone": settings.timezone,
        "currency": settings.currency,
    }
