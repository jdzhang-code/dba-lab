#!/usr/bin/env bash
# health-check.sh — PostgreSQL daily health check (cron-friendly)
# Usage: ./health-check.sh  (add to crontab for daily runs)
set -euo pipefail

PGUSER="${PGUSER:-postgres}"
DB="${DB:-postgres}"
LOG="health-$(date +%F).log"

check() { echo "### $1"; }

{
  check "connections"
  psql -U "$PGUSER" -d "$DB" -tAc \
    "SELECT count(*) FROM pg_stat_activity;"

  check "long running queries (>5min)"
  psql -U "$PGUSER" -d "$DB" -c \
    "SELECT pid, now()-query_start AS duration, query FROM pg_stat_activity
     WHERE state='active' AND now()-query_start > interval '5 minutes';"

  check "disk usage"
  df -h /var/lib/postgresql | tail -1

  check "replication lag (on standby)"
  psql -U "$PGUSER" -d "$DB" -tAc \
    "SELECT CASE WHEN pg_is_in_recovery()
       THEN pg_last_wal_replay_lag()::text ELSE 'not a standby' END;"
} | tee "$LOG"
