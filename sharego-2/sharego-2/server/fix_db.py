import sqlite3

conn = sqlite3.connect('sharego.db')
cursor = conn.cursor()

tables = cursor.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
table_names = [t[0] for t in tables]
print("Existing tables:", table_names)

if 'notifications' not in table_names:
    print("Creating notifications table...")
    cursor.execute("""
        CREATE TABLE notifications (
            id INTEGER PRIMARY KEY,
            user_id INTEGER NOT NULL,
            type VARCHAR NOT NULL,
            title VARCHAR NOT NULL,
            body VARCHAR NOT NULL,
            is_read BOOLEAN NOT NULL DEFAULT 0,
            route VARCHAR,
            created_at DATETIME NOT NULL
        )
    """)
    cursor.execute("CREATE INDEX ix_notifications_user_id ON notifications (user_id)")
    cursor.execute("CREATE INDEX ix_notifications_type ON notifications (type)")
    cursor.execute("CREATE INDEX ix_notifications_created_at ON notifications (created_at)")
    conn.commit()
    print("SUCCESS! notifications table created.")
else:
    print("notifications table already exists!")

current = cursor.execute("SELECT * FROM alembic_version").fetchall()
versions = [v[0] for v in current]
if 'cc8959337598' not in versions:
    cursor.execute("INSERT INTO alembic_version VALUES ('cc8959337598')")
    conn.commit()
if '105ba3408bc5' not in versions:
    cursor.execute("INSERT INTO alembic_version VALUES ('105ba3408bc5')")
    conn.commit()

print("Done! Versions:", cursor.execute("SELECT * FROM alembic_version").fetchall())
conn.close()
