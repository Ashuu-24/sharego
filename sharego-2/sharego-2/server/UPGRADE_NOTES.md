# UPGRADE_NOTES

## Migration from `create_all` to Alembic

1. Install dependencies:
   - `pip install -r requirements.txt`
2. Apply migrations:
   - `alembic upgrade head`
3. Start API:
   - `uvicorn app.main:app --reload --port 8000`

## Important behavior change

- Startup no longer runs `SQLModel.metadata.create_all(...)`.
- Startup validates schema and raises if tables are missing/outdated (dev/strict mode).
- Keep schema changes in Alembic revisions only.

## Existing local DB

- If your local `Flyro.db` was created by the old runtime `create_all` flow:
  - `python -m alembic stamp 20260210_0001`
  - `python -m alembic upgrade head`
- If your local DB already contains mixed/new columns and migrations fail:
  - backup `Flyro.db`
  - delete `Flyro.db`
  - run `python -m alembic upgrade head`
