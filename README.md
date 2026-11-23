# Snowflake Analytics Agent (Claude Code + Snowflake)

An AI coding agent (Claude Code) that writes and runs its own SQL and Python against a live Snowflake data warehouse, inside guardrails: **read-only access, its own compute budget, key-pair login, and a validation checklist for every number it produces.**

> Built as a hands-on learning project to answer one question: *how do you let an AI agent work on real data without trusting it blindly?*

## Why this project

Most people use AI for analytics through one-off chat prompts: copy the query, paste the error, repeat. An **agent** closes that loop itself (plan → write SQL → run it → read the result or error → fix). That makes it faster, and riskier. This project focuses on the two things that make an agent safe to use:

1. **Controlled access:** the agent physically cannot change data or overspend.
2. **Validation:** a query that *runs* is not the same as a query that's *right*.

## Architecture

```
Laptop (project folder = the agent's sandbox)
  Claude Code ──► scripts/*.py ──► snowflake-connector-python
                     │                (key-pair / JWT auth)
                     ▼
Snowflake
  AGENT_USER (TYPE=SERVICE, no password)
    └─ role AGENT_READONLY (SELECT only)
         ├─ warehouse AGENT_WH (X-Small, auto-suspend 60s)
         │     └─ resource monitor: 5 credits/month, suspend at 100%
         └─ SNOWFLAKE_SAMPLE_DATA.TPCH_SF1 (orders, lineitem, customer, nation, region)
```

## Security design (least privilege)

| Layer | Control | Why |
|---|---|---|
| Data | `AGENT_READONLY` role with SELECT only | The agent can't INSERT, UPDATE, DELETE or DROP |
| Compute | Dedicated `AGENT_WH`, X-Small, auto-suspend 60s | Agent usage is isolated and visible in billing |
| Cost | Resource monitor, 5 credits/month | A runaway loop can't burn the account's credits |
| Identity | `AGENT_USER` with `TYPE = SERVICE` and key-pair auth | No password to leak or phish; queries are audited as the agent |
| Secrets | Private key stored in `~/.snowflake`, outside the project | The agent's workspace never contains the key |
| Config | `.env` (gitignored) holds settings, `.env.example` shows the format | No account details in code or on GitHub |

**Tested, not assumed:** as `AGENT_READONLY`, a `SELECT` works, while `DELETE`, switching to another warehouse and `CREATE DATABASE` are all rejected. See [`setup/snowflake_setup.sql`](setup/snowflake_setup.sql).

## Validation: how I check the agent's answers

Example question, deliberately vague: *"What was total revenue by region in 1997?"*

The agent stated its assumptions before answering:
1. Revenue = `SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT))`: after discount, before tax (TPC-H standard)
2. Region = the **customer's** region (orders → customer → nation → region)
3. 1997 = by **order date**

| Region | Revenue (1997) |
|---|---:|
| AMERICA | 6,656,020,934.07 |
| ASIA | 6,644,477,021.03 |
| EUROPE | 6,612,330,499.50 |
| AFRICA | 6,584,856,827.28 |
| MIDDLE EAST | 6,551,711,218.41 |

**Checklist used on every result:**
- **Reconcile:** grouped totals must equal the *same* metric calculated without the grouping joins. (My first check failed because I compared against `O_TOTALPRICE`, which includes tax: a different definition, not a bug.)
- **Join fan-out:** compare `COUNT(*)` with `COUNT(DISTINCT key)` after joins, to catch duplicated rows.
- **Definitions:** confirm which business definition a metric uses before trusting it. The business decides, not the agent.

Query: [`queries/revenue_by_region.sql`](queries/revenue_by_region.sql)

## Project structure

```
analytics-agent/
├── queries/                  # saved SQL (the agent writes here)
│   └── revenue_by_region.sql
├── scripts/
│   ├── test_connection.py    # smoke test: who am I, which role/warehouse, row count
│   └── run_query.py          # run any .sql file and save the result as CSV
├── setup/
│   └── snowflake_setup.sql   # warehouse, budget, role, service user, security tests
├── outputs/                  # query results (gitignored)
├── .env.example              # settings template (real .env is gitignored)
└── .gitignore
```

## How to run it

1. Run `setup/snowflake_setup.sql` in Snowflake as ACCOUNTADMIN.
2. Generate a key pair (Git Bash), keeping it **outside** the project:
   ```bash
   mkdir -p ~/.snowflake && cd ~/.snowflake
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out agent_key.p8 -nocrypt
   openssl rsa -in agent_key.p8 -pubout -out agent_key.pub
   ```
   Paste the public key into the `CREATE USER` statement.
3. Set up Python:
   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install snowflake-connector-python python-dotenv pandas
   ```
4. Copy `.env.example` to `.env` and fill in your account identifier and key path.
5. Test, then run a query:
   ```powershell
   python scripts/test_connection.py
   python scripts/run_query.py queries/revenue_by_region.sql outputs/revenue_by_region.csv
   ```

## What I learned

- Security you haven't tested is just a hope: always test the forbidden actions too.
- Agents guess business definitions. Good ones say so; your job is to confirm or correct them.
- Real-world friction teaches the most: case-sensitive Snowflake identifiers, Windows script execution policy, and the difference between public and private keys.

## Next steps

- `CLAUDE.md` with business definitions and validation rules, so every agent session follows them
- Parameterized query templates (`{start_date}`, `{end_date}`)
- A `run_report.py` with built-in assertions for a repeatable weekly report

## Tech

Snowflake · SQL · Python (snowflake-connector-python, python-dotenv) · Claude Code · Git
