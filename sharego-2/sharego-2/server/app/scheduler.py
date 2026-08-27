"""APScheduler jobs — runs inside the FastAPI lifespan."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from apscheduler.schedulers.background import BackgroundScheduler
from sqlmodel import Session, select

from app.core.audit import write_audit_log
from app.core.config import get_settings
from app.db import engine
from app.models import Booking, BookingStatus, EscrowTx, MarketListing

logger = logging.getLogger(__name__)

EXPIRY_HOURS = 48

scheduler = BackgroundScheduler()


def expire_stale_bookings() -> None:
    """Transition REQUESTED/HOLD_PLACED bookings older than 48h to EXPIRED."""
    cutoff = datetime.utcnow() - timedelta(hours=EXPIRY_HOURS)
    with Session(engine) as session:
        stale = session.exec(
            select(Booking).where(
                Booking.status.in_([BookingStatus.REQUESTED.value, BookingStatus.HOLD_PLACED.value]),
                Booking.created_at < cutoff,
            )
        ).all()

        if not stale:
            return

        count = 0
        for booking in stale:
            booking.status = BookingStatus.EXPIRED.value
            booking.updated_at = datetime.utcnow()
            session.add(booking)

            # Refund escrow if exists.
            escrow = session.exec(
                select(EscrowTx).where(
                    EscrowTx.booking_id == booking.id,
                    EscrowTx.status == "hold",
                )
            ).first()
            if escrow:
                escrow.status = "refunded"
                session.add(escrow)

            count += 1

        session.commit()

        # Audit log outside the main loop to avoid commit-per-row overhead.
        for booking in stale:
            write_audit_log(
                session,
                actor="scheduler",
                action="BOOKING_EXPIRED_AUTO",
                entity=f"booking:{booking.id}",
                after={"status": BookingStatus.EXPIRED.value, "reason": f"stale>{EXPIRY_HOURS}h"},
            )

        logger.info("Expired %d stale booking(s) older than %dh", count, EXPIRY_HOURS)


def expire_stale_listings() -> None:
    """Transition ACTIVE listings older than listing_expiry_days to expired."""
    settings = get_settings()
    expiry_days = 30
    cutoff = datetime.utcnow() - timedelta(days=expiry_days)
    with Session(engine) as session:
        stale = session.exec(
            select(MarketListing).where(
                MarketListing.status == "active",
                MarketListing.created_at < cutoff,
            )
        ).all()

        if not stale:
            return

        count = 0
        for listing in stale:
            listing.status = "expired"
            listing.updated_at = datetime.utcnow()
            session.add(listing)
            count += 1

        session.commit()

        for listing in stale:
            write_audit_log(
                session,
                actor="scheduler",
                action="LISTING_EXPIRED_AUTO",
                entity=f"market_listing:{listing.id}",
                after={"status": "expired", "reason": f"stale>{expiry_days}d"},
            )

        logger.info("Expired %d stale listing(s) older than %d days", count, expiry_days)


def start_scheduler() -> None:
    scheduler.add_job(
        expire_stale_bookings,
        "interval",
        minutes=30,
        id="expire_stale_bookings",
        replace_existing=True,
    )
    scheduler.add_job(
        expire_stale_listings,
        "interval",
        hours=6,
        id="expire_stale_listings",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started — expire_stale_bookings every 30 min, expire_stale_listings every 6h")


def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Scheduler stopped")
