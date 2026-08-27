# Flyro Backend (FastAPI + SQLite)

This is the backend scaffold for Flyro. Stack: FastAPI, SQLite (`Flyro.db`), Jinja2 admin, optional MinIO for media.

## Quick start (planned)
- Create a `.env` from `.env.example`.
- Install dependencies and run Alembic migrations.
- Start FastAPI (uvicorn) with reload during development.

## Migrations (required)
- Initialize/upgrade database schema before running app:
  - `python -m alembic upgrade head`
- App startup no longer auto-creates tables. In dev/strict mode it raises if schema is behind.

## Feature A booking endpoints
- `POST /bookings`
- `GET /bookings`
- `GET /bookings/{id}`
- `POST /bookings/{id}/accept`
- `POST /bookings/{id}/decline`
- `POST /bookings/{id}/cancel`
- `POST /bookings/{id}/pickup/verify`
- `POST /bookings/{id}/delivery/verify`
- `POST /bookings/{id}/expire` (admin-only stub for scheduler parity)
- `POST /admin/escrow/{id}/release`
- `POST /admin/escrow/{id}/refund`

## OTP issuance for handover (QA note)
- Pickup and delivery OTP codes are generated during `POST /bookings`.
- Only bcrypt hashes are stored in DB (`pickup_code_hash`, `delivery_code_hash`); plaintext is never persisted.
- In `dev` env only, response includes `pickup_otp_dev` and `delivery_otp_dev` for test/demo flows.
- Codes are one-time: each hash is consumed and cleared after successful verify endpoints.

## Configuration (env)
See `.env.example` for required values: PKR currency, Asia/Karachi timezone, JWT secret, OTP SMTP, media root, MinIO (optional).

## Admin web login
- Browser admin panel now supports cookie auth:
  - `GET /admin/login`
  - `POST /admin/login`
  - `POST /admin/logout`
- Login requires an account with `admin` or `ops` role and a stored `password_hash`.
- Cookie settings are configurable via:
  - `ADMIN_COOKIE_NAME`
  - `ADMIN_SESSION_MINUTES`
  - `ADMIN_COOKIE_SECURE`
  - `ADMIN_COOKIE_SAMESITE`

## Media
- Default: local filesystem `./media` mounted at `/media`.
- MinIO: optional via env; not enabled by default.

## Persistence
- SQLite via SQLModel (`Flyro.db`) + Alembic migrations.

## Tests
- For now, run with plugins disabled to avoid system-wide pytest plugins interfering:
  - `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q`
  - `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest --maxfail=1 -q`

Tests currently cover:
- Health endpoint
- Auth OTP request/verify (hashed + persisted OTP, user creation, JWT claims)

## Seed
- Run `python seed.py` to insert a demo user/trip if DB is empty.

## Warnings (to address later)
- httpx TestClient transport shortcut deprecation (switch to WSGITransport/ASGITransport when convenient).
