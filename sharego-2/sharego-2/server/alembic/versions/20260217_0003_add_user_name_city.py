"""add name and city columns to user table

Revision ID: 20260217_0003
Revises: 20260210_0002
Create Date: 2026-02-17 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260217_0003"
down_revision = "20260210_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user", sa.Column("name", sa.String(), nullable=True))
    op.add_column("user", sa.Column("city", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("user", "city")
    op.drop_column("user", "name")
