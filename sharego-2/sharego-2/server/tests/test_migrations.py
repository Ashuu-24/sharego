from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect


def test_alembic_upgrade_head_creates_expected_tables(tmp_path):
    server_dir = Path(__file__).resolve().parents[1]
    db_path = tmp_path / "migrations_test.db"

    cfg = Config(str(server_dir / "alembic.ini"))
    cfg.set_main_option("script_location", str(server_dir / "alembic"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite:///{db_path.as_posix()}")

    command.upgrade(cfg, "head")

    engine = create_engine(f"sqlite:///{db_path.as_posix()}")
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    expected = {
        "user",
        "otpentry",
        "trip",
        "kycprofile",
        "requests",
        "bookings",
        "escrow_tx",
        "wallet_entries",
        "handover_events",
        "market_listings",
        "market_offers",
        "market_meetups",
        "reviews",
        "disputes",
        "dispute_evidence",
        "feature_flags",
        "audit_logs",
        "otp_throttles",
        "messages",
    }
    assert expected.issubset(tables)
