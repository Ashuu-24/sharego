from fastapi import APIRouter

router = APIRouter(tags=["admin"])


@router.get("/admin")
async def admin_placeholder():
    return {"message": "Admin panel will be added in Sprint 5 (Jinja2)."}
