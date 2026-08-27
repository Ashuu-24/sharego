"""baseline existing schema

Revision ID: 20260210_0001
Revises:
Create Date: 2026-02-10 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260210_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("phone", sa.String(), nullable=True),
        sa.Column("roles_csv", sa.String(), nullable=False, server_default="user"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_user_email", "user", ["email"], unique=False)

    op.create_table(
        "otpentry",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("hashed_code", sa.String(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="3"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_otpentry_email", "otpentry", ["email"], unique=False)

    op.create_table(
        "trip",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("origin_airport", sa.String(), nullable=False),
        sa.Column("dest_airport", sa.String(), nullable=False),
        sa.Column("date", sa.DateTime(), nullable=False),
        sa.Column("capacity_kg", sa.Float(), nullable=False),
        sa.Column("fee_pkr", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_trip_user_id", "trip", ["user_id"], unique=False)
    op.create_index("ix_trip_origin_airport", "trip", ["origin_airport"], unique=False)
    op.create_index("ix_trip_dest_airport", "trip", ["dest_airport"], unique=False)

    op.create_table(
        "kycprofile",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pending"),
        sa.Column("doc_type", sa.String(), nullable=True),
        sa.Column("doc_url", sa.String(), nullable=True),
        sa.Column("selfie_url", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_kycprofile_user_id", "kycprofile", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_kycprofile_user_id", table_name="kycprofile")
    op.drop_table("kycprofile")
    op.drop_index("ix_trip_dest_airport", table_name="trip")
    op.drop_index("ix_trip_origin_airport", table_name="trip")
    op.drop_index("ix_trip_user_id", table_name="trip")
    op.drop_table("trip")
    op.drop_index("ix_otpentry_email", table_name="otpentry")
    op.drop_table("otpentry")
    op.drop_index("ix_user_email", table_name="user")
    op.drop_table("user")
