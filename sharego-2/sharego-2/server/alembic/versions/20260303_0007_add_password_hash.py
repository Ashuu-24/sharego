"""add password_hash to user

Revision ID: 20260303_0007
Revises: 20260302_0006
Create Date: 2026-03-03 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260303_0007"
down_revision = "7856932b318f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user", sa.Column("password_hash", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("user", "password_hash")
