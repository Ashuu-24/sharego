"""Jinja2 server-rendered admin panel.

All admin pages require admin/ops auth. Mutation actions (approve, reject,
release, refund, flag) call the existing JSON API services under the hood so
business rules stay in one place.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
import jinja2
from fastapi.templating import Jinja2Templates
from sqlmodel import Session, col, func, select

from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse

from app.api.deps import get_current_user_dep, get_session_dep, get_settings_dep
from app.core.audit import write_audit_log
from app.core.config import Settings
from app.models import (
    AuditLog,
    Booking,
    BookingStatus,
    BookingUpdate,
    EscrowTx,
    FeatureFlag,
    HandoverEvent,
    KYCProfile,
    MarketListing,
    Message,
    Review,
    Trip,
    User,
    WalletEntry,
)
from app.domain.ledger_reasons import LedgerReason

_templates_dir = Path(__file__).resolve().parents[3] / "templates"

env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(str(_templates_dir)),
    autoescape=jinja2.select_autoescape(),
    cache_size=0,
)

templates = Jinja2Templates(env=env)

def _require_admin(user: User = Depends(get_current_user_dep)) -> User:
    if "admin" not in user.roles and "ops" not in user.roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


router = APIRouter(prefix="/admin", tags=["admin-panel"], dependencies=[Depends(_require_admin)])


# ═══════════════════════════════════════════════════════════════════════
#  DASHBOARD
# ═══════════════════════════════════════════════════════════════════════

@router.get("", response_class=HTMLResponse)
async def dashboard(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    now = datetime.utcnow()
    day_ago = now - timedelta(hours=24)

    # Active booking statuses (neither terminal nor initial).
    active_statuses = {
        BookingStatus.HOLD_PLACED.value,
        BookingStatus.ACCEPTED.value,
        BookingStatus.PICKUP_OK.value,
        BookingStatus.DELIVERY_OK.value,
    }

    stats = {
        "total_users": session.exec(select(func.count(User.id))).one() or 0,
        "pending_kyc": session.exec(
            select(func.count(KYCProfile.id)).where(KYCProfile.status == "pending")
        ).one() or 0,
        "active_bookings": session.exec(
            select(func.count(Booking.id)).where(col(Booking.status).in_(active_statuses))
        ).one() or 0,
        "released_bookings": session.exec(
            select(func.count(Booking.id)).where(Booking.status == BookingStatus.RELEASED.value)
        ).one() or 0,
        "active_listings": session.exec(
            select(func.count(MarketListing.id)).where(MarketListing.status == "active")
        ).one() or 0,
        "sold_listings": session.exec(
            select(func.count(MarketListing.id)).where(MarketListing.status == "sold")
        ).one() or 0,
        "total_reviews": session.exec(select(func.count(Review.id))).one() or 0,
        "recent_audit": session.exec(
            select(func.count(AuditLog.id)).where(col(AuditLog.ts) >= day_ago)
        ).one() or 0,
    }

    recent_bookings = session.exec(
        select(Booking).order_by(col(Booking.created_at).desc()).limit(10)
    ).all()
    recent_listings = session.exec(
        select(MarketListing).order_by(col(MarketListing.created_at).desc()).limit(10)
    ).all()

    return templates.TemplateResponse(request, "dashboard.html", {
        "request": request,
        "page": "dashboard",
        "env": settings.env,
        "stats": stats,
        "recent_bookings": recent_bookings,
        "recent_listings": recent_listings,
    })


# ═══════════════════════════════════════════════════════════════════════
#  KYC QUEUE
# ═══════════════════════════════════════════════════════════════════════

@router.get("/kyc", response_class=HTMLResponse)
async def kyc_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    profiles = session.exec(
        select(KYCProfile).where(KYCProfile.status == "pending")
    ).all()
    processed = session.exec(
        select(KYCProfile)
        .where(col(KYCProfile.status).in_(["approved", "rejected"]))
        .order_by(col(KYCProfile.updated_at).desc())
        .limit(20)
    ).all()
    return templates.TemplateResponse(request, "kyc.html", {
        "request": request,
        "page": "kyc",
        "env": settings.env,
        "profiles": profiles,
        "processed": processed,
    })


@router.post("/kyc-action/{user_id}/approve")
async def kyc_approve_action(
    user_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    profile = session.exec(
        select(KYCProfile).where(KYCProfile.user_id == user_id)
    ).first()
    if profile:
        profile.status = "approved"
        profile.updated_at = datetime.utcnow()
        session.add(profile)
        user = session.get(User, user_id)
        if user:
            user.kyc_status = "approved"
            session.add(user)
        session.commit()
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="kyc_approved",
            entity=f"kyc_profile:{profile.id}",
            before={"status": "pending"},
            after={"status": "approved"},
        )
    return RedirectResponse(url="/admin/kyc", status_code=303)


@router.post("/kyc-action/{user_id}/reject")
async def kyc_reject_action(
    user_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    profile = session.exec(
        select(KYCProfile).where(KYCProfile.user_id == user_id)
    ).first()
    if profile:
        profile.status = "rejected"
        profile.updated_at = datetime.utcnow()
        session.add(profile)
        user = session.get(User, user_id)
        if user:
            user.kyc_status = "rejected"
            session.add(user)
        session.commit()
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="kyc_rejected",
            entity=f"kyc_profile:{profile.id}",
            before={"status": "pending"},
            after={"status": "rejected"},
        )
    return RedirectResponse(url="/admin/kyc", status_code=303)


# ═══════════════════════════════════════════════════════════════════════
#  TRIPS QUEUE
# ═══════════════════════════════════════════════════════════════════════

@router.get("/trips", response_class=HTMLResponse)
async def trips_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    pending = session.exec(
        select(Trip).where(Trip.status == "pending_review").order_by(col(Trip.created_at).desc())
    ).all()
    processed = session.exec(
        select(Trip)
        .where(col(Trip.status).in_(["approved", "rejected"]))
        .order_by(col(Trip.created_at).desc())
        .limit(20)
    ).all()

    # Build display wrappers with user info (SQLModel objects reject unknown attrs).
    user_cache: dict[int, User | None] = {}

    def _trip_row(t: Trip) -> dict:
        if t.user_id not in user_cache:
            user_cache[t.user_id] = session.get(User, t.user_id)
        u = user_cache.get(t.user_id)
        return {
            **{c: getattr(t, c) for c in t.__class__.__fields__},
            "user_name": getattr(u, "name", None) or f"User #{t.user_id}",
            "user_email": getattr(u, "email", None) or "",
        }

    pending_rows = [_trip_row(t) for t in pending]
    processed_rows = [_trip_row(t) for t in processed]

    return templates.TemplateResponse(request, "trips.html", {
        "request": request,
        "page": "trips",
        "env": settings.env,
        "pending": pending_rows,
        "processed": processed_rows,
    })


@router.post("/trip-action/{trip_id}/approve")
async def trip_approve_action(
    trip_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    trip = session.get(Trip, trip_id)
    if trip and trip.status == "pending_review":
        old_status = trip.status
        trip.status = "approved"
        session.add(trip)
        session.commit()
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="trip_approved",
            entity=f"trip:{trip_id}",
            before={"status": old_status},
            after={"status": "approved"},
        )
    return RedirectResponse(url="/admin/trips", status_code=303)


@router.post("/trip-action/{trip_id}/reject")
async def trip_reject_action(
    trip_id: int,
    request: Request,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    trip = session.get(Trip, trip_id)
    if trip and trip.status == "pending_review":
        form = await request.form()
        reason = str(form.get("reason", "")).strip() or None
        old_status = trip.status
        trip.status = "rejected"
        trip.reject_reason = reason
        session.add(trip)
        session.commit()
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="trip_rejected",
            entity=f"trip:{trip_id}",
            before={"status": old_status},
            after={"status": "rejected", "reject_reason": reason},
        )
    return RedirectResponse(url="/admin/trips", status_code=303)


@router.get("/flight-status/{trip_id}")
async def admin_flight_status(
    trip_id: int,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    """JSON endpoint: fetch live flight status for a trip (used by admin JS)."""
    from app.api.routes.trips import fetch_flight_status

    trip = session.get(Trip, trip_id)
    if not trip:
        return JSONResponse({"error": "Trip not found"}, status_code=404)
    if not trip.flight_number:
        return JSONResponse({"error": "No flight number"}, status_code=400)
    if not settings.aviationstack_api_key:
        return JSONResponse({"error": "Flight tracking not configured"}, status_code=503)

    return await fetch_flight_status(trip.flight_number, settings.aviationstack_api_key)


# ═══════════════════════════════════════════════════════════════════════
#  WALLETS
# ═══════════════════════════════════════════════════════════════════════

@router.get("/wallets", response_class=HTMLResponse)
async def wallets_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    from app.domain.escrow.service import _current_balance

    # KPI: total across all wallets, escrow hold, released, refunded
    total_balance = session.exec(
        select(func.coalesce(func.sum(WalletEntry.delta), 0.0))
    ).one() or 0.0
    total_hold = session.exec(
        select(func.coalesce(func.sum(EscrowTx.amount), 0.0)).where(EscrowTx.status == "hold")
    ).one() or 0.0
    total_released = session.exec(
        select(func.coalesce(func.sum(EscrowTx.amount), 0.0)).where(EscrowTx.status == "released")
    ).one() or 0.0
    total_refunded = session.exec(
        select(func.coalesce(func.sum(EscrowTx.amount), 0.0)).where(EscrowTx.status == "refunded")
    ).one() or 0.0

    kpi = {
        "total_balance": float(total_balance),
        "total_hold": float(total_hold),
        "total_released": float(total_released),
        "total_refunded": float(total_refunded),
    }

    # User balances
    users = session.exec(select(User).order_by(col(User.id))).all()
    user_balances = []
    for u in users:
        bal = _current_balance(session, u.id)
        user_balances.append({"id": u.id, "email": u.email, "name": u.name or f"User #{u.id}", "balance": bal})

    # Recent transactions
    recent_entries = session.exec(
        select(WalletEntry).order_by(col(WalletEntry.created_at).desc()).limit(30)
    ).all()
    # Build display wrappers with user info (SQLModel objects reject unknown attrs).
    entry_user_cache: dict[int, User | None] = {}
    entry_rows = []
    for e in recent_entries:
        if e.user_id not in entry_user_cache:
            entry_user_cache[e.user_id] = session.get(User, e.user_id)
        u = entry_user_cache.get(e.user_id)
        entry_rows.append({
            **{c: getattr(e, c) for c in e.__class__.__fields__},
            "user_name": getattr(u, "name", None) or f"User #{e.user_id}",
        })

    return templates.TemplateResponse(request, "wallets.html", {
        "request": request,
        "page": "wallets",
        "env": settings.env,
        "kpi": kpi,
        "user_balances": user_balances,
        "recent_entries": entry_rows,
    })


@router.post("/wallet-action/{user_id}/topup")
async def wallet_topup_action(
    user_id: int,
    request: Request,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    from app.domain.escrow.service import _add_wallet_entry
    form = await request.form()
    raw_amount = form.get("amount", "0") or "0"
    amount = float(raw_amount)
    if amount > 0:
        _add_wallet_entry(
            session,
            user_id=user_id,
            delta=amount,
            reason=LedgerReason.ADMIN_TOPUP,
            ref_id="admin_panel",
        )
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="WALLET_TOPUP",
            entity=f"user:{user_id}",
            after={"amount": amount},
        )
    return RedirectResponse(url="/admin/wallets", status_code=303)


# ═══════════════════════════════════════════════════════════════════════
#  BOOKINGS
# ═══════════════════════════════════════════════════════════════════════

@router.get("/bookings", response_class=HTMLResponse)
async def bookings_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    rows = session.exec(
        select(Booking).order_by(col(Booking.created_at).desc())
    ).all()

    # Attach escrow info to each booking for the template.
    bookings = []
    for b in rows:
        escrow = session.exec(
            select(EscrowTx).where(EscrowTx.booking_id == b.id)
        ).first()
        entry = {c: getattr(b, c) for c in b.__class__.model_fields}
        entry["escrow_status"] = escrow.status if escrow else None
        entry["escrow_amount"] = escrow.amount if escrow else None
        bookings.append(entry)

    handover_events = session.exec(
        select(HandoverEvent).order_by(col(HandoverEvent.ts).desc()).limit(20)
    ).all()

    return templates.TemplateResponse(request, "bookings.html", {
        "request": request,
        "page": "bookings",
        "env": settings.env,
        "bookings": bookings,
        "handover_events": handover_events,
    })


@router.post("/booking-action/{booking_id}/release")
async def booking_release_action(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    from app.domain.escrow.service import release
    release(session, booking_id=booking_id, admin_id=admin_user.id, request_id=f"admin:{admin_user.email}")
    return RedirectResponse(url="/admin/bookings", status_code=303)


@router.post("/booking-action/{booking_id}/refund")
async def booking_refund_action(
    booking_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    from app.domain.escrow.service import refund
    refund(session, booking_id=booking_id, admin_id=admin_user.id, request_id=f"admin:{admin_user.email}")
    return RedirectResponse(url="/admin/bookings", status_code=303)


@router.get("/booking-detail/{booking_id}", response_class=HTMLResponse)
async def booking_detail_page(
    request: Request,
    booking_id: int,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    booking = session.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")

    escrow = session.exec(
        select(EscrowTx).where(EscrowTx.booking_id == booking_id)
    ).first()

    trip = session.get(Trip, booking.trip_id)
    from app.models import RequestItem
    req = session.get(RequestItem, booking.request_id)

    # Traveler status updates
    updates = session.exec(
        select(BookingUpdate)
        .where(BookingUpdate.booking_id == booking_id)
        .order_by(col(BookingUpdate.created_at).asc())
    ).all()

    # Messages linked to this booking
    messages_raw = session.exec(
        select(Message)
        .where(Message.booking_id == booking_id)
        .order_by(col(Message.created_at).asc())
    ).all()

    user_cache: dict[int, User | None] = {}
    def _get_user_name(uid: int) -> str:
        if uid not in user_cache:
            user_cache[uid] = session.get(User, uid)
        u = user_cache[uid]
        return (u.name or u.email) if u else f"User #{uid}"

    msg_rows = []
    for m in messages_raw:
        msg_rows.append({
            "id": m.id,
            "sender_name": _get_user_name(m.sender_id),
            "receiver_name": _get_user_name(m.receiver_id),
            "content": m.content,
            "created_at": m.created_at,
            "read_at": m.read_at,
        })

    update_rows = []
    for u in updates:
        update_rows.append({
            "update_type": u.update_type,
            "note": u.note,
            "created_at": u.created_at,
            "user_name": _get_user_name(u.user_id),
        })

    return templates.TemplateResponse(request, "booking_detail.html", {
        "request": request,
        "page": "bookings",
        "env": settings.env,
        "booking": booking,
        "escrow": escrow,
        "trip": trip,
        "buyer_request": req,
        "traveler_name": _get_user_name(trip.user_id) if trip else "Unknown",
        "buyer_name": _get_user_name(req.user_id) if req else "Unknown",
        "updates": update_rows,
        "messages": msg_rows,
    })


# ═══════════════════════════════════════════════════════════════════════
#  MARKETPLACE MODERATION
# ═══════════════════════════════════════════════════════════════════════

@router.get("/marketplace", response_class=HTMLResponse)
async def marketplace_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    listings = session.exec(
        select(MarketListing).order_by(col(MarketListing.created_at).desc())
    ).all()

    stats = {
        "active": sum(1 for l in listings if l.status == "active"),
        "sold": sum(1 for l in listings if l.status == "sold"),
        "paused": sum(1 for l in listings if l.status == "paused"),
        "flagged": sum(1 for l in listings if l.status == "flagged"),
    }

    return templates.TemplateResponse(request, "marketplace.html", {
        "request": request,
        "page": "marketplace",
        "env": settings.env,
        "listings": listings,
        "stats": stats,
    })


@router.post("/market-action/{listing_id}/flag")
async def market_flag_action(
    listing_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    listing = session.get(MarketListing, listing_id)
    if listing:
        old_status = listing.status
        listing.status = "flagged"
        listing.updated_at = datetime.utcnow()
        session.add(listing)
        session.commit()
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="listing_flagged",
            entity=f"market_listing:{listing_id}",
            before={"status": old_status},
            after={"status": "flagged"},
        )
    return RedirectResponse(url="/admin/marketplace", status_code=303)


@router.post("/market-action/{listing_id}/unflag")
async def market_unflag_action(
    listing_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    listing = session.get(MarketListing, listing_id)
    if listing and listing.status == "flagged":
        listing.status = "active"
        listing.updated_at = datetime.utcnow()
        session.add(listing)
        session.commit()
        write_audit_log(
            session,
            actor=f"admin:{admin_user.email}",
            action="listing_unflagged",
            entity=f"market_listing:{listing_id}",
            before={"status": "flagged"},
            after={"status": "active"},
        )
    return RedirectResponse(url="/admin/marketplace", status_code=303)


# ═══════════════════════════════════════════════════════════════════════
#  AUDIT LOG
# ═══════════════════════════════════════════════════════════════════════

@router.get("/audit", response_class=HTMLResponse)
async def audit_page(
    request: Request,
    action: str | None = None,
    actor: str | None = None,
    entity: str | None = None,
    page: int = Query(default=1, ge=1),
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    page_size = 50
    query = select(AuditLog)
    if action:
        query = query.where(AuditLog.action == action)
    if actor:
        query = query.where(AuditLog.actor == actor)
    if entity:
        query = query.where(col(AuditLog.entity).contains(entity))

    total = session.exec(select(func.count()).select_from(query.subquery())).one() or 0
    total_pages = max(1, (total + page_size - 1) // page_size)
    offset = (page - 1) * page_size
    logs = session.exec(
        query.order_by(col(AuditLog.ts).desc()).offset(offset).limit(page_size)
    ).all()

    # Get distinct action values for filter dropdown
    available_actions = [
        r for r in session.exec(select(AuditLog.action).distinct()).all()
    ]
    # Get distinct actor values for filter dropdown
    available_actors = [
        r for r in session.exec(
            select(AuditLog.actor).distinct().where(AuditLog.actor.isnot(None))
        ).all()
    ]

    return templates.TemplateResponse(request, "audit.html", {
        "request": request,
        "page": "audit",
        "env": settings.env,
        "logs": logs,
        "total": total,
        "current_page": page,
        "total_pages": total_pages,
        "filter_action": action,
        "filter_actor": actor,
        "filter_entity": entity,
        "available_actions": sorted(available_actions),
        "available_actors": sorted(available_actors),
    })


@router.get("/audit-api")
async def audit_api(
    action: str | None = None,
    actor: str | None = None,
    entity: str | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    session: Session = Depends(get_session_dep),
):
    query = select(AuditLog)
    if action:
        query = query.where(AuditLog.action == action)
    if actor:
        query = query.where(AuditLog.actor == actor)
    if entity:
        query = query.where(col(AuditLog.entity).contains(entity))

    total = session.exec(select(func.count()).select_from(query.subquery())).one() or 0
    offset = (page - 1) * page_size
    logs = session.exec(
        query.order_by(col(AuditLog.ts).desc()).offset(offset).limit(page_size)
    ).all()

    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "items": [
            {
                "id": l.id,
                "actor": l.actor,
                "action": l.action,
                "entity": l.entity,
                "before": l.before,
                "after": l.after,
                "request_id": l.request_id,
                "ts": l.ts.isoformat() if l.ts else None,
            }
            for l in logs
        ],
    }


# ═══════════════════════════════════════════════════════════════════════
#  FEATURE FLAGS (HTML)
# ═══════════════════════════════════════════════════════════════════════

@router.get("/flags", response_class=HTMLResponse)
async def flags_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    flags = session.exec(select(FeatureFlag)).all()
    return templates.TemplateResponse(request, "feature_flags.html", {
        "request": request,
        "page": "flags",
        "env": settings.env,
        "flags": flags,
    })


@router.post("/flags-action/create")
async def flags_create_action(
    request: Request,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    form = await request.form()
    key = str(form.get("key", "")).strip()
    value = str(form.get("value", "true")).strip()
    cohort = str(form.get("cohort", "")).strip() or None
    if key:
        existing = session.exec(select(FeatureFlag).where(FeatureFlag.key == key)).first()
        if not existing:
            flag = FeatureFlag(key=key, value=value, cohort=cohort)
            session.add(flag)
            session.commit()
            write_audit_log(session, actor=f"admin:{admin_user.email}", action="flag_created", entity=f"feature_flag:{key}", after={"value": value})
    return RedirectResponse(url="/admin/flags", status_code=303)


@router.post("/flags-action/{flag_id}/toggle")
async def flags_toggle_action(
    flag_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    flag = session.get(FeatureFlag, flag_id)
    if flag:
        old = flag.value
        flag.value = "false" if flag.value == "true" else "true"
        flag.updated_at = datetime.utcnow()
        session.add(flag)
        session.commit()
        write_audit_log(
            session, actor=f"admin:{admin_user.email}", action="flag_toggled",
            entity=f"feature_flag:{flag.id}", before={"value": old}, after={"value": flag.value},
        )
    return RedirectResponse(url="/admin/flags", status_code=303)


@router.post("/flags-action/{flag_id}/delete")
async def flags_delete_action(
    flag_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    flag = session.get(FeatureFlag, flag_id)
    if flag:
        write_audit_log(session, actor=f"admin:{admin_user.email}", action="flag_deleted", entity=f"feature_flag:{flag.id}", before={"key": flag.key})
        session.delete(flag)
        session.commit()
    return RedirectResponse(url="/admin/flags", status_code=303)


# ═══════════════════════════════════════════════════════════════════════
#  USERS MANAGEMENT (HTML)
# ═══════════════════════════════════════════════════════════════════════

@router.get("/users", response_class=HTMLResponse)
async def users_page(
    request: Request,
    session: Session = Depends(get_session_dep),
    settings: Settings = Depends(get_settings_dep),
):
    users = session.exec(select(User).order_by(col(User.id))).all()
    return templates.TemplateResponse(request, "users.html", {
        "request": request,
        "page": "users",
        "env": settings.env,
        "users": users,
    })


@router.post("/user-action/{user_id}/make-admin")
async def user_make_admin(
    user_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    user = session.get(User, user_id)
    if user and "admin" not in user.roles:
        roles = user.roles + ["admin"]
        user.roles_csv = ",".join(roles)
        session.add(user)
        session.commit()
        write_audit_log(session, actor=f"admin:{admin_user.email}", action="role_changed", entity=f"user:{user_id}", after={"roles": user.roles_csv})
    return RedirectResponse(url="/admin/users", status_code=303)


@router.post("/user-action/{user_id}/remove-admin")
async def user_remove_admin(
    user_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    user = session.get(User, user_id)
    if user and "admin" in user.roles:
        roles = [r for r in user.roles if r != "admin"]
        user.roles_csv = ",".join(roles) if roles else "user"
        session.add(user)
        session.commit()
        write_audit_log(session, actor=f"admin:{admin_user.email}", action="role_changed", entity=f"user:{user_id}", after={"roles": user.roles_csv})
    return RedirectResponse(url="/admin/users", status_code=303)


@router.post("/user-action/{user_id}/delete")
async def user_delete(
    user_id: int,
    session: Session = Depends(get_session_dep),
    admin_user: User = Depends(_require_admin),
):
    user = session.get(User, user_id)
    if not user:
        return RedirectResponse(url="/admin/users", status_code=303)
    if user.id == admin_user.id:
        return RedirectResponse(url="/admin/users", status_code=303)
    before = {"email": user.email, "name": user.name, "roles": user.roles_csv}
    session.delete(user)
    session.commit()
    write_audit_log(session, actor=f"admin:{admin_user.email}", action="user_deleted", entity=f"user:{user_id}", before=before)
    return RedirectResponse(url="/admin/users", status_code=303)
