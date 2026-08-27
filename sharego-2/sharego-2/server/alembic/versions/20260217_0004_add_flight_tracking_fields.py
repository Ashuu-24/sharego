"""add flight_number and airline columns to trip table

Revision ID: 20260217_0004
Revises: 20260217_0003
Create Date: 2026-02-17 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260217_0004"
down_revision = "20260217_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("trip", sa.Column("flight_number", sa.String(), nullable=True))
    op.add_column("trip", sa.Column("airline", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("trip", "airline")
    op.drop_column("trip", "flight_number")
