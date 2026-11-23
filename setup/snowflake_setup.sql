-- One-time Snowflake setup for the analytics agent (run as ACCOUNTADMIN).
-- Principle: least privilege. The agent gets its own compute, its own budget,
-- its own read-only role and its own key-pair login.

USE ROLE ACCOUNTADMIN;

-- 1. Dedicated compute: smallest size, switches off after 60s idle
CREATE WAREHOUSE IF NOT EXISTS agent_wh
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- 2. Budget guard: warn at 80%, stop at 100% of 5 credits per month
CREATE RESOURCE MONITOR IF NOT EXISTS agent_monitor
  WITH CREDIT_QUOTA = 5
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE agent_wh SET RESOURCE_MONITOR = agent_monitor;

-- 3. Read-only role
CREATE ROLE IF NOT EXISTS agent_readonly;
GRANT USAGE ON WAREHOUSE agent_wh TO ROLE agent_readonly;
GRANT IMPORTED PRIVILEGES ON DATABASE snowflake_sample_data TO ROLE agent_readonly;

-- 4. Machine user with key-pair auth (no password, no UI login)
--    Paste the public key body (without the BEGIN/END lines) below.
CREATE USER IF NOT EXISTS agent_user
  TYPE = SERVICE
  DEFAULT_ROLE = agent_readonly
  DEFAULT_WAREHOUSE = agent_wh
  RSA_PUBLIC_KEY = '<PASTE_PUBLIC_KEY_HERE>';
GRANT ROLE agent_readonly TO USER agent_user;

-- 5. Security tests: run as the agent's role
-- USE ROLE agent_readonly;
-- USE WAREHOUSE agent_wh;
-- SELECT COUNT(*) FROM snowflake_sample_data.tpch_sf1.orders;  -- works (1,500,000)
-- DELETE FROM snowflake_sample_data.tpch_sf1.orders;           -- fails: insufficient privileges
-- USE WAREHOUSE compute_wh;                                     -- fails: not authorized
-- CREATE DATABASE agent_playground;                             -- fails: insufficient privileges
