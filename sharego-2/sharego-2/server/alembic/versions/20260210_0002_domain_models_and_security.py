"""add domain models and security tables

Revision ID: 20260210_0002
Revises: 20260210_0001
Create Date: 2026-02-10 00:10:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260210_0002"
down_revision = "20260210_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user", sa.Column("kyc_status", sa.String(), nullable=False, server_default="pending"))
    op.add_column("user", sa.Column("rating_avg", sa.Float(), nullable=False, server_default="0.0"))

    op.create_table(
        "otp_throttles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("ip_address", sa.String(), nullable=False),
        sa.Column("window_start", sa.DateTime(), nullable=False),
        sa.Column("count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_otp_throttles_email", "otp_throttles", ["email"], unique=False)
    op.create_index("ix_otp_throttles_ip_address", "otp_throttles", ["ip_address"], unique=False)

    op.create_table(
        "requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("product_name", sa.String(), nullable=False),
        sa.Column("specs_json", sa.String(), nullable=True),
        sa.Column("target_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("dest_city", sa.String(), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("window_start", sa.DateTime(), nullable=False),
        sa.Column("window_end", sa.DateTime(), nullable=False),
        sa.Column("declaration_path", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_requests_user_id", "requests", ["user_id"], unique=False)

    op.create_table(
        "bookings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("request_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="REQUESTED"),
        sa.Column("waybill", sa.String(), nullable=True),
        sa.Column("pickup_code_hash", sa.String(), nullable=True),
        sa.Column("delivery_code_hash", sa.String(), nullable=True),
        sa.Column("seal_id", sa.String(), nullable=True),
        sa.Column("receipt_path", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_bookings_trip_id", "bookings", ["trip_id"], unique=False)
    op.create_index("ix_bookings_request_id", "bookings", ["request_id"], unique=False)
    op.create_index("ix_bookings_status", "bookings", ["status"], unique=False)

    op.create_table(
        "escrow_tx",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False, server_default="PKR"),
        sa.Column("status", sa.String(), nullable=False, server_default="hold"),
        sa.Column("provider", sa.String(), nullable=False, server_default="virtual"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_escrow_tx_booking_id", "escrow_tx", ["booking_id"], unique=False)
    op.create_index("ix_escrow_tx_status", "escrow_tx", ["status"], unique=False)

    op.create_table(
        "wallet_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("delta", sa.Float(), nullable=False),
        sa.Column("balance_after", sa.Float(), nullable=False),
        sa.Column("reason", sa.String(), nullable=False),
        sa.Column("ref_id", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_wallet_entries_user_id", "wallet_entries", ["user_id"], unique=False)

    op.create_table(
        "handover_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column("gps_lat", sa.Float(), nullable=True),
        sa.Column("gps_lng", sa.Float(), nullable=True),
        sa.Column("photos_paths", sa.String(), nullable=True),
        sa.Column("seal_id", sa.String(), nullable=True),
        sa.Column("ts", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_handover_events_booking_id", "handover_events", ["booking_id"], unique=False)

    op.create_table(
        "market_listings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("seller_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=False),
        sa.Column("photos_paths", sa.String(), nullable=True),
        sa.Column("category", sa.String(), nullable=True),
        sa.Column("condition", sa.String(), nullable=True),
        sa.Column("location_text", sa.String(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("ask_price", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False, server_default="PKR"),
        sa.Column("contact_pref", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_market_listings_seller_id", "market_listings", ["seller_id"], unique=False)
    op.create_index("ix_market_listings_title", "market_listings", ["title"], unique=False)
    op.create_index("ix_market_listings_category", "market_listings", ["category"], unique=False)
    op.create_index("ix_market_listings_location_text", "market_listings", ["location_text"], unique=False)
    op.create_index("ix_market_listings_ask_price", "market_listings", ["ask_price"], unique=False)
    op.create_index("ix_market_listings_status", "market_listings", ["status"], unique=False)

    op.create_table(
        "market_offers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("listing_id", sa.Integer(), nullable=False),
        sa.Column("from_user_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False, server_default="PKR"),
        sa.Column("message", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="SENT"),
        sa.Column("ts", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_market_offers_listing_id", "market_offers", ["listing_id"], unique=False)
    op.create_index("ix_market_offers_from_user_id", "market_offers", ["from_user_id"], unique=False)
    op.create_index("ix_market_offers_status", "market_offers", ["status"], unique=False)

    op.create_table(
        "market_meetups",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("listing_id", sa.Integer(), nullable=False),
        sa.Column("buyer_id", sa.Integer(), nullable=False),
        sa.Column("seller_id", sa.Integer(), nullable=False),
        sa.Column("place_text", sa.String(), nullable=False),
        sa.Column("scheduled_ts", sa.DateTime(), nullable=False),
        sa.Column("otp_hash", sa.String(), nullable=True),
        sa.Column("confirmed_ts", sa.DateTime(), nullable=True),
        sa.Column("note", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_market_meetups_listing_id", "market_meetups", ["listing_id"], unique=False)
    op.create_index("ix_market_meetups_buyer_id", "market_meetups", ["buyer_id"], unique=False)
    op.create_index("ix_market_meetups_seller_id", "market_meetups", ["seller_id"], unique=False)

    op.create_table(
        "reviews",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("reviewer_id", sa.Integer(), nullable=False),
        sa.Column("reviewee_id", sa.Integer(), nullable=False),
        sa.Column("target_type", sa.String(), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("comment", sa.String(), nullable=True),
        sa.Column("ts", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reviews_reviewer_id", "reviews", ["reviewer_id"], unique=False)
    op.create_index("ix_reviews_reviewee_id", "reviews", ["reviewee_id"], unique=False)
    op.create_index("ix_reviews_target_type", "reviews", ["target_type"], unique=False)
    op.create_index("ix_reviews_target_id", "reviews", ["target_id"], unique=False)

    op.create_table(
        "disputes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("target_type", sa.String(), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("opened_by", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="open"),
        sa.Column("resolution", sa.String(), nullable=True),
        sa.Column("ts_open", sa.DateTime(), nullable=False),
        sa.Column("ts_close", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_disputes_target_type", "disputes", ["target_type"], unique=False)
    op.create_index("ix_disputes_target_id", "disputes", ["target_id"], unique=False)
    op.create_index("ix_disputes_opened_by", "disputes", ["opened_by"], unique=False)
    op.create_index("ix_disputes_status", "disputes", ["status"], unique=False)

    op.create_table(
        "dispute_evidence",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("dispute_id", sa.Integer(), nullable=False),
        sa.Column("by_user", sa.Integer(), nullable=False),
        sa.Column("file_path", sa.String(), nullable=False),
        sa.Column("note", sa.String(), nullable=True),
        sa.Column("ts", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_dispute_evidence_dispute_id", "dispute_evidence", ["dispute_id"], unique=False)
    op.create_index("ix_dispute_evidence_by_user", "dispute_evidence", ["by_user"], unique=False)

    op.create_table(
        "feature_flags",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("value", sa.String(), nullable=False),
        sa.Column("cohort", sa.String(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("key"),
    )
    op.create_index("ix_feature_flags_key", "feature_flags", ["key"], unique=False)

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("actor", sa.String(), nullable=True),
        sa.Column("action", sa.String(), nullable=False),
        sa.Column("entity", sa.String(), nullable=False),
        sa.Column("before", sa.String(), nullable=True),
        sa.Column("after", sa.String(), nullable=True),
        sa.Column("request_id", sa.String(), nullable=True),
        sa.Column("ts", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_audit_logs_actor", "audit_logs", ["actor"], unique=False)
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"], unique=False)
    op.create_index("ix_audit_logs_entity", "audit_logs", ["entity"], unique=False)
    op.create_index("ix_audit_logs_request_id", "audit_logs", ["request_id"], unique=False)
    op.create_index("ix_audit_logs_ts", "audit_logs", ["ts"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_audit_logs_ts", table_name="audit_logs")
    op.drop_index("ix_audit_logs_request_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_entity", table_name="audit_logs")
    op.drop_index("ix_audit_logs_action", table_name="audit_logs")
    op.drop_index("ix_audit_logs_actor", table_name="audit_logs")
    op.drop_table("audit_logs")

    op.drop_index("ix_feature_flags_key", table_name="feature_flags")
    op.drop_table("feature_flags")

    op.drop_index("ix_dispute_evidence_by_user", table_name="dispute_evidence")
    op.drop_index("ix_dispute_evidence_dispute_id", table_name="dispute_evidence")
    op.drop_table("dispute_evidence")

    op.drop_index("ix_disputes_status", table_name="disputes")
    op.drop_index("ix_disputes_opened_by", table_name="disputes")
    op.drop_index("ix_disputes_target_id", table_name="disputes")
    op.drop_index("ix_disputes_target_type", table_name="disputes")
    op.drop_table("disputes")

    op.drop_index("ix_reviews_target_id", table_name="reviews")
    op.drop_index("ix_reviews_target_type", table_name="reviews")
    op.drop_index("ix_reviews_reviewee_id", table_name="reviews")
    op.drop_index("ix_reviews_reviewer_id", table_name="reviews")
    op.drop_table("reviews")

    op.drop_index("ix_market_meetups_seller_id", table_name="market_meetups")
    op.drop_index("ix_market_meetups_buyer_id", table_name="market_meetups")
    op.drop_index("ix_market_meetups_listing_id", table_name="market_meetups")
    op.drop_table("market_meetups")

    op.drop_index("ix_market_offers_status", table_name="market_offers")
    op.drop_index("ix_market_offers_from_user_id", table_name="market_offers")
    op.drop_index("ix_market_offers_listing_id", table_name="market_offers")
    op.drop_table("market_offers")

    op.drop_index("ix_market_listings_status", table_name="market_listings")
    op.drop_index("ix_market_listings_ask_price", table_name="market_listings")
    op.drop_index("ix_market_listings_location_text", table_name="market_listings")
    op.drop_index("ix_market_listings_category", table_name="market_listings")
    op.drop_index("ix_market_listings_title", table_name="market_listings")
    op.drop_index("ix_market_listings_seller_id", table_name="market_listings")
    op.drop_table("market_listings")

    op.drop_index("ix_handover_events_booking_id", table_name="handover_events")
    op.drop_table("handover_events")

    op.drop_index("ix_wallet_entries_user_id", table_name="wallet_entries")
    op.drop_table("wallet_entries")

    op.drop_index("ix_escrow_tx_status", table_name="escrow_tx")
    op.drop_index("ix_escrow_tx_booking_id", table_name="escrow_tx")
    op.drop_table("escrow_tx")

    op.drop_index("ix_bookings_status", table_name="bookings")
    op.drop_index("ix_bookings_request_id", table_name="bookings")
    op.drop_index("ix_bookings_trip_id", table_name="bookings")
    op.drop_table("bookings")

    op.drop_index("ix_requests_user_id", table_name="requests")
    op.drop_table("requests")

    op.drop_index("ix_otp_throttles_ip_address", table_name="otp_throttles")
    op.drop_index("ix_otp_throttles_email", table_name="otp_throttles")
    op.drop_table("otp_throttles")

    op.drop_column("user", "rating_avg")
    op.drop_column("user", "kyc_status")
