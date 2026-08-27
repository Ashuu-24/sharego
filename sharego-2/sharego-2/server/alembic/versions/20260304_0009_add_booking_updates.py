"""add booking_updates table

Revision ID: 20260304_0009
Revises: 20260303_0008
Create Date: 2026-03-04 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260304_0009"
down_revision = "20260303_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "booking_updates",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("update_type", sa.String(), nullable=False),
        sa.Column("note", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_booking_updates_booking_id", "booking_updates", ["booking_id"])
    op.create_index("ix_booking_updates_user_id", "booking_updates", ["user_id"])
    op.create_index("ix_booking_updates_update_type", "booking_updates", ["update_type"])


def downgrade() -> None:
    op.drop_index("ix_booking_updates_update_type", "booking_updates")
    op.drop_index("ix_booking_updates_user_id", "booking_updates")
    op.drop_index("ix_booking_updates_booking_id", "booking_updates")
    op.drop_table("booking_updates")
