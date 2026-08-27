"""add passport_url to kycprofile

Revision ID: 20260303_0008
Revises: 20260303_0007
Create Date: 2026-03-03 00:00:01.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260303_0008"
down_revision = "20260303_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("kycprofile", sa.Column("passport_url", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("kycprofile", "passport_url")
