import sqlite3
con = sqlite3.connect("sharego.db")
rows = con.execute("""
    select user_id, sum(delta) as computed_balance
    from wallet_entries group by user_id
""").fetchall()
for user_id, computed in rows:
    last_balance_after = con.execute(
        "select balance_after from wallet_entries where user_id=? order by created_at desc limit 1",
        (user_id,),
    ).fetchone()[0]
    status = "OK" if abs(computed - last_balance_after) < 0.01 else "MISMATCH"
    print(user_id, computed, last_balance_after, status)