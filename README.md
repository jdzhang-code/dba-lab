# DBA Lab — PostgreSQL Operations Practice

Hands-on lab notes from my PostgreSQL DBA sprint: backup & recovery, replication, failover, monitoring scripts.

## Lab Index

| # | Lab | Status |
|---|-----|--------|
| 01 | Backup & PITR recovery (`pg_basebackup` + WAL) | ⬜ |
| 02 | Streaming replication + lag monitoring | ⬜ |
| 03 | Failover drill + runbook | ⬜ |
| 04 | Troubleshooting: locks, connections, disk full | ⬜ |

## Environment

- PostgreSQL 16 (Docker)
- Linux / macOS + Bash
- Python 3.11+ (psycopg) — from week 4

## Layout

- `sql/` — SQL practice queries
- `postgres-lab/` — one folder per lab, each with its own README (steps + output)
- `scripts/` — health-check / backup scripts
- `docs/` — runbooks and SOPs
