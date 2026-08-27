import sqlite3

con = sqlite3.connect("sharego.db")
print(con.execute(
    "select name from sqlite_master where type='table' and name='bank_accounts'"
).fetchall())
print(con.execute("pragma table_info(bank_accounts)").fetchall())