"""Run a .sql file against Snowflake and save the result as CSV.

Usage: python scripts/run_query.py queries/<name>.sql outputs/<name>.csv
"""

import csv
import os
import sys

import snowflake.connector
from dotenv import load_dotenv

sql_path, csv_path = sys.argv[1], sys.argv[2]

load_dotenv()

with open(sql_path, encoding="utf-8") as f:
    sql = f.read()

conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    role=os.environ["SNOWFLAKE_ROLE"],
    warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    authenticator="SNOWFLAKE_JWT",
    private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
)

try:
    cur = conn.cursor()
    cur.execute(sql)
    columns = [col[0] for col in cur.description]
    rows = cur.fetchall()
    cur.close()
finally:
    conn.close()

with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(columns)
    writer.writerows(rows)

print(f"Saved {len(rows)} rows to {csv_path}")
for row in [columns, *rows]:
    print(" | ".join(str(v) for v in row))
