from __future__ import annotations

import logging
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.parse import urlencode

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from jose import JWTError, jwt
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.staticfiles import StaticFiles

from app.api.routes import api_router
from app.core.audit import write_audit_log
from app.core.config import get_settings
from app.core.errors import error_payload, register_error_handlers
from app.core.limits import limiter
from app.db import ensure_schema_ready, session_scope
from app.scheduler import start_scheduler, stop_scheduler
from app.api.routes import notifications


def _parse_csv(raw: str) -> list[str]:
    return [item.strip() for item in raw.split(",") if item.strip()]


def _validate_security_settings(settings) -> None:
    if settings.env in {"dev", "test"}:
        return
    weak_secrets = {"change_me", "changeme", "secret", "default", "password"}
    if len(settings.jwt_secret) < 32 or settings.jwt_secret.lower() in weak_secrets:
        raise RuntimeError("JWT_SECRET must be at least 32 characters and not use a default value")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()

    media_root = Path(settings.media_root)
    media_root.mkdir(parents=True, exist_ok=True)
    static_root = Path(settings.static_root)
    static_root.mkdir(parents=True, exist_ok=True)

    strict_check = settings.migration_required_strict or settings.env == "dev"
    ensure_schema_ready(strict=strict_check)
    start_scheduler()
    yield
    stop_scheduler()


def create_application() -> FastAPI:
    settings = get_settings()
    _validate_security_settings(settings)
    media_root = Path(settings.media_root)
    static_root = Path(settings.static_root)
    media_root.mkdir(parents=True, exist_ok=True)
    static_root.mkdir(parents=True, exist_ok=True)
    docs_enabled = settings.env == "dev" or settings.api_docs_enabled

    logging.basicConfig(
        level=logging.INFO if settings.env == "dev" else logging.WARNING,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs" if docs_enabled else None,
        redoc_url="/redoc" if docs_enabled else None,
        openapi_url="/openapi.json" if docs_enabled else None,
    )
    app.state.limiter = limiter

    async def _rate_limit_handler(_request: Request, _exc: RateLimitExceeded):
        return JSONResponse(
            status_code=429,
            content=error_payload("rate_limited", "Too many requests"),
        )

    app.add_exception_handler(RateLimitExceeded, _rate_limit_handler)
    app.add_middleware(SlowAPIMiddleware)

    trusted_hosts = _parse_csv(settings.trusted_hosts)
    if settings.env in {"dev", "test"}:
        for local_host in ("testserver", "localhost", "127.0.0.1"):
            if local_host not in trusted_hosts:
                trusted_hosts.append(local_host)
    if trusted_hosts and "*" not in trusted_hosts:
        app.add_middleware(TrustedHostMiddleware, allowed_hosts=trusted_hosts)

    cors_origins = _parse_csv(settings.cors_allowed_origins)

    # Dev mode: allow ALL localhost ports (Flutter web picks a random port).
    # allow_origin_regex + credentials is legal; wildcard ["*"] + credentials is not.
    if settings.env in {"dev", "test"}:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=[],
            allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    else:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=cors_origins,
            allow_credentials=bool(cors_origins and "*" not in cors_origins),
            allow_methods=["*"],
            allow_headers=["*"],
        )

    register_error_handlers(app)

    app.include_router(api_router)
    app.include_router(notifications.router)


    @app.middleware("http")
    async def request_context_middleware(request: Request, call_next):
        start = time.time()
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = request_id
        response = None
        path = request.url.path

        if path.startswith("/admin"):
            admin_auth_header = request.headers.get("authorization")
            admin_cookie = request.cookies.get(settings.admin_cookie_name)
            login_or_logout = path.startswith("/admin/login") or path == "/admin/logout"
            invalid_admin_cookie = False

            if admin_cookie and not login_or_logout:
                try:
                    decode_kwargs = {"algorithms": [settings.jwt_alg]}
                    if settings.jwt_issuer:
                        decode_kwargs["issuer"] = settings.jwt_issuer
                    if settings.jwt_audience:
                        decode_kwargs["audience"] = settings.jwt_audience
                    payload = jwt.decode(admin_cookie, settings.jwt_secret, **decode_kwargs)
                    if not payload.get("sub"):
                        invalid_admin_cookie = True
                except JWTError:
                    invalid_admin_cookie = True

            if not admin_auth_header and admin_cookie and not login_or_logout and not invalid_admin_cookie:
                # Bridge admin auth cookie to Bearer header so existing auth dependencies keep working.
                request.scope["headers"] = [
                    *request.scope["headers"],
                    (b"authorization", f"Bearer {admin_cookie}".encode("utf-8")),
                ]
                admin_auth_header = "cookie"

            accepts_html = "text/html" in request.headers.get("accept", "")
            if (
                request.method == "GET"
                and not login_or_logout
                and not admin_auth_header
                and accepts_html
            ):
                next_path = request.url.path
                if request.url.query:
                    next_path = f"{next_path}?{request.url.query}"
                response = RedirectResponse(
                    url=f"/admin/login?{urlencode({'next': next_path})}",
                    status_code=status.HTTP_303_SEE_OTHER,
                )
                if invalid_admin_cookie:
                    response.delete_cookie(settings.admin_cookie_name, path="/admin")

        if response is None:
            response = await call_next(request)
        response.headers["x-request-id"] = request_id
        if settings.security_headers_enabled:
            response.headers.setdefault("X-Content-Type-Options", "nosniff")
            response.headers.setdefault("X-Frame-Options", "DENY")
            response.headers.setdefault("Referrer-Policy", "no-referrer")
            response.headers.setdefault("Permissions-Policy", "camera=(), microphone=(), geolocation=()")

        duration_ms = (time.time() - start) * 1000
        logging.info(
            "request_id=%s path=%s method=%s status=%s duration_ms=%.2f",
            request_id,
            request.url.path,
            request.method,
            response.status_code,
            duration_ms,
        )

        # Lightweight audit hook for mutations on key routes.
        audit_prefixes = ("/admin", "/bookings", "/market", "/kyc", "/trips", "/requests", "/reviews")
        if any(request.url.path.startswith(p) for p in audit_prefixes) and request.method in {"POST", "PATCH", "DELETE"}:
            with session_scope() as session:
                write_audit_log(
                    session,
                    actor="middleware",
                    action=f"HTTP_{request.method}",
                    entity=request.url.path,
                    request_id=request_id,
                    after={"status_code": response.status_code},
                )
        return response

    app.mount(settings.media_base_url, StaticFiles(directory=str(media_root)), name="media")
    app.mount("/static", StaticFiles(directory=str(static_root)), name="static")
    return app


app = create_application()