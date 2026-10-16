# Lab 01 — Backup & PITR Recovery

## Goal
Take a base backup with `pg_basebackup`, enable WAL archiving, then recover the database to a specific point in time after a simulated data loss.

## Steps
1. `initdb` / start PostgreSQL 16 in Docker
2. Create test database, insert sample rows, note the time
3. `pg_basebackup -D /backup/base -Ft -z -P`
4. Configure `archive_mode = on`, `archive_command`
5. Simulate disaster: `DROP TABLE orders;`
6. Recover: stop server → restore base backup → `recovery_target_time` → start → verify rows

## Result
- [ ] Base backup completed, size: ___
- [ ] PITR recovered to ___, rows verified: ___

## Gotchas
_(write down what tripped you up — this is the most valuable part)_
-
