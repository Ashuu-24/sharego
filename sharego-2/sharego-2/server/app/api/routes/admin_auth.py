from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Depends, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlmodel import Session, select

from app.api.deps import get_request_id_dep, get_session_dep, get_settings_dep
from app.core.audit import write_audit_log
from app.core.config import Settings
from app.core.security import create_access_token, verify_password
from app.models import User
import jinja2
from fastapi.templating import Jinja2Templates

_templates_dir = Path(__file__).resolve().parents[3] / "templates"

env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(str(_templates_dir)),
    autoescape=jinja2.select_autoescape(),
    cache_size=0,
)

templates = Jinja2Templates(env=env)

router = APIRouter(prefix="/admin", tags=["admin-auth"])


def _safe_next(next_path: str | None) -> str:
    if not next_path:
        return "/admin"
    candidate = next_path.strip()
    if not candidate.startswith("/admin"):
        return "/admin"
    return candidate


def _admin_cookie_security(settings: Settings) -> tuple[bool, str]:
    secure_cookie = settings.admin_cookie_secure or settings.env not in {"dev", "test"}
    samesite = settings.admin_cookie_samesite.lower().strip()
    if samesite not in {"strict", "lax", "none"}:
        samesite = "strict"
    if samesite == "none":
        secure_cookie = True
    return secure_cookie, samesite


@router.get("/login", response_class=HTMLResponse)
async def admin_login_page(
    request: Request,
    next: str | None = None,
    settings: Settings = Depends(get_settings_dep),
):
    if request.cookies.get(settings.admin_cookie_name):
        return RedirectResponse(url=_safe_next(next), status_code=status.HTTP_303_SEE_OTHER)
    return templates.TemplateResponse(
        request,
        "admin_login.html",
        {
            "request": request,
            "env": settings.env,
            "next": _safe_next(next),
            "error": None,
        },
    )


@router.post("/login", response_class=HTMLResponse)
async def admin_login_submit(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
    request_id: str = Depends(get_request_id_dep),
):
    form = await request.form()
    email = str(form.get("email", "")).strip().lower()
    password = str(form.get("password", ""))
    next_path = _safe_next(str(form.get("next", "/admin")))

    def _render_error(message: str, status_code: int) -> HTMLResponse:
        return templates.TemplateResponse(
            request,
            "admin_login.html",
            {
                "request": request,
                "env": settings.env,
                "next": next_path,
                "error": message,
            },
            status_code=status_code,
        )

    if not email or not password:
        return _render_error("Email and password are required.", status.HTTP_400_BAD_REQUEST)

    user = session.exec(select(User).where(User.email == email)).first()
    if not user or not user.password_hash or not verify_password(password, user.password_hash):
        return _render_error("Invalid email or password.", status.HTTP_401_UNAUTHORIZED)
    if "admin" not in user.roles and "ops" not in user.roles:
        return _render_error("Admin access required for this account.", status.HTTP_403_FORBIDDEN)

    token = create_access_token(
        subject=user.email,
        settings=settings,
        expires_minutes=settings.admin_session_minutes,
        extra_claims={"roles": user.roles},
    )
    secure_cookie, samesite = _admin_cookie_security(settings)

    response = RedirectResponse(url=next_path, status_code=status.HTTP_303_SEE_OTHER)
    response.set_cookie(
        key=settings.admin_cookie_name,
        value=token,
        max_age=settings.admin_session_minutes * 60,
        httponly=True,
        secure=secure_cookie,
        samesite=samesite,
        path="/admin",
    )
    write_audit_log(
        session,
        actor=str(user.id),
        action="ADMIN_LOGIN_SUCCESS",
        entity="admin_auth",
        request_id=request_id,
        after={"email": user.email},
    )
    return response


@router.post("/logout")
async def admin_logout(
    request: Request,
    settings: Settings = Depends(get_settings_dep),
):
    response = RedirectResponse(url="/admin/login", status_code=status.HTTP_303_SEE_OTHER)
    response.delete_cookie(settings.admin_cookie_name, path="/admin")
    return response

