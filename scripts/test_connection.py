"""Smoke test: connect to Snowflake with key-pair auth and run two read-only queries."""

import os

import snowflake.connector
from dotenv import load_dotenv

# Load SNOWFLAKE_* settings from the .env file in the project root.
load_dotenv()

# The connector reads the key file itself; this script only passes its path.
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

    cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()")
    user, role, warehouse = cur.fetchone()
    print(f"User: {user} | Role: {role} | Warehouse: {warehouse}")

    cur.execute("SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS")
    (order_count,) = cur.fetchone()
    print(f"TPCH_SF1.ORDERS row count: {order_count:,}")

    cur.close()
finally:
    conn.close()
    print("Connection closed.")
