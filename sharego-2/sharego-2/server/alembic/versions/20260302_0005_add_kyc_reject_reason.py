"""add reject_reason column to kycprofile table

Revision ID: 20260302_0005
Revises: 20260217_0004
Create Date: 2026-03-02 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260302_0005"
down_revision = "20260217_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("kycprofile", sa.Column("reject_reason", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("kycprofile", "reject_reason")
