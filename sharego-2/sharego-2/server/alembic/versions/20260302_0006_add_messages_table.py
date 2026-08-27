"""add messages table

Revision ID: 20260302_0006
Revises: 20260302_0005
Create Date: 2026-03-02 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "20260302_0006"
down_revision = "20260302_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "messages",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("sender_id", sa.Integer(), nullable=False, index=True),
        sa.Column("receiver_id", sa.Integer(), nullable=False, index=True),
        sa.Column("content", sa.String(), nullable=False),
        sa.Column("booking_id", sa.Integer(), nullable=True, index=True),
        sa.Column("listing_id", sa.Integer(), nullable=True, index=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("read_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("messages")
