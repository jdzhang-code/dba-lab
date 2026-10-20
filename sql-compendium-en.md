# SQL Compendium (Oct 17 – Oct 19, 2026)

> **One-line guide**: Ten SQL study emails from three days, deduplicated, polished, and reorganized by topic — from SELECT basics, JOINs, and window functions to NULL three-valued logic, anti-joins, performance tuning, and DBA practice. The companion `emp` table is shared throughout (see Section 0); LeetCode problems use MySQL dialect, with Postgres translations where they matter.

**Table of Contents**

- [0. Companion table and conventions](#0-companion-table-and-conventions)
- [1. Basics: SELECT, execution order, data types, INSERT](#1-basics-select-execution-order-data-types-insert)
- [2. JOIN: INNER / LEFT / self-join / CROSS JOIN](#2-join-inner--left--self-join--cross-join)
- [3. Subqueries in three positions + UNION](#3-subqueries-in-three-positions--union)
- [4. Aggregation: DISTINCT, COUNT, GROUP BY, HAVING](#4-aggregation-distinct-count-group-by-having)
- [5. Window functions](#5-window-functions)
- [6. NULL three-valued logic deep dive](#6-null-three-valued-logic-deep-dive)
- [7. Three anti-join patterns](#7-three-anti-join-patterns)
- [8. WITH (CTE)](#8-with-cte)
- [9. CASE WHEN / COALESCE / conditional aggregation](#9-case-when--coalesce--conditional-aggregation)
- [10. Date functions](#10-date-functions)
- [11. High-frequency patterns](#11-high-frequency-patterns)
- [12. Performance: naked columns, slow queries, indexes, EXPLAIN](#12-performance-naked-columns-slow-queries-indexes-explain)
- [13. DBA practice](#13-dba-practice)
- [14. Strings / regex / UPDATE / DELETE](#14-strings--regex--update--delete)
- [15. LeetCode 10-problem walkthrough](#15-leetcode-10-problem-walkthrough)
- [16. Appendix](#16-appendix)

---

## 0. Companion table and conventions

The `emp` table shared throughout (`#27/#29/#30` used the same one):

| name | dept | salary | phone | email | bonus | hire_date |
|------|-------|--------|----------|--------------|-------|------------|
| Zhang San | IT | 9000 | 1380001 | zhang@x.com | 1000 | 2024-01-05 |
| Li Si | IT | 5000 | NULL | lisi@x.com | NULL | 2024-01-20 |
| Wang Wu | Sales | 8000 | 1380003 | NULL | 500 | 2024-02-10 |
| Zhao Liu | Sales | 6000 | NULL | NULL | 300 | 2024-02-15 |
| Qian Qi | HR | 10000 | 1380005 | qianqi@x.com | NULL | 2024-03-01 |

**Dialect convention**: LeetCode practice uses MySQL dialect; starting W1D3 we switch to Postgres, with comparison tables at the key differences. Uppercase SQL keywords are a writing habit, not a requirement.

---

## 1. Basics: SELECT, execution order, data types, INSERT

### 1.1 What is SQL

SQL (Structured Query Language) is the language for talking to **relational databases**. You say *what data you want*, not *how to find it* — that is its biggest difference from Python.

| Category | Keywords | Purpose |
|---|---|---|
| Query | `SELECT` | Read data (90% of the work) |
| Definition | `CREATE / ALTER / DROP` | Create / alter table structure |
| Manipulation | `INSERT / UPDATE / DELETE` | Add / change / remove data |
| Control | `GRANT / REVOKE` | Permission management |

From a DBA's view: `SELECT` is the stethoscope (check slow queries, locks, status), `GRANT` is the prescription, `EXPLAIN` is the X-ray.

```sql
SELECT city, name, total_spent
FROM customers
WHERE total_spent > 1000
ORDER BY total_spent DESC
LIMIT 3;
```

### 1.2 What is PostgreSQL

The strongest open-source relational database — "hard currency" for DBA gigs:

- **Two birds with one stone**: `CREATE EXTENSION vector;` turns it into a vector database, reused on the RAG data pipeline
- **MVCC**: reads don't block writes — the backbone of high concurrency (a must-ask in interviews)
- **WAL**: write-ahead log — the foundation of backup/recovery and replication
- Learn PG first, then MySQL takes a day; the reverse doesn't work

### 1.3 How to read the symbols

| Symbol | Pronunciation | Meaning in SQL |
|---|---|---|
| `%` | percent; "mod" when doing arithmetic | wildcard in `LIKE 'A%'`; remainder in `year % 2` |
| `*` | asterisk; "star" in `SELECT *` | select all columns |

`%` has two meanings depending on position: between numbers it's modulo (`WHERE year % 2 = 0` finds even years), after `LIKE` it's a wildcard.

### 1.4 Write order ≠ execution order

```
FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT/OFFSET
```

Three implications:

1. **WHERE can't use SELECT aliases**, ORDER BY can (SELECT hasn't run when WHERE runs)
2. **WHERE can't use aggregate functions**, HAVING can (no grouping has happened when WHERE runs)
3. **Filter as early as possible**: write it in WHERE instead of HAVING whenever you can — less data downstream means less work everywhere

Full example (numbers = execution order):

```sql
SELECT d.name AS department,          -- ⑥
       COUNT(*) AS headcount,
       AVG(e.salary) AS avg_salary
FROM employees e                       -- ①
JOIN departments d                     -- ②
  ON e.dept_id = d.id
WHERE e.salary > 50000                 -- ③ row-level filter
GROUP BY d.name                        -- ④ grouping
HAVING AVG(e.salary) > 80000           -- ⑤ group-level filter
ORDER BY avg_salary DESC                -- ⑦ alias OK here
LIMIT 5;                               -- ⑧
```

Mnemonic: WHERE filters rows, HAVING filters groups.

### 1.5 Data types

**Enum**: a type restricted to a few fixed values — rejects dirty data at insert time.

```sql
-- MySQL
status ENUM('pending', 'paid', 'shipped', 'done')

-- PostgreSQL
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'shipped', 'done');
```

**VARCHAR vs INT vs BIGINT vs DECIMAL**:

| Type | Stores | Size |
|---|---|---|
| VARCHAR(n) | text (variable length) | up to n characters |
| SMALLINT | integers | 2 bytes, ±32k |
| INT | integers | 4 bytes, ±2.1 billion |
| BIGINT | integers | 8 bytes, ±9 quintillion |

- Use BIGINT for primary-key ids (the 2.1B INT ceiling really does get hit)
- Never use INT for money — use DECIMAL (floating-point precision trap)
- Use VARCHAR for phone numbers (they're not numbers; they can have leading zeros)

### 1.6 INSERT

```sql
-- Movies column order: (id, title, director, year, length_minutes)
INSERT INTO Movies (id, title, director, year, length_minutes)
VALUES (4, 'Toy Story', 'John Lasseter', 1995, 81);
```

- Strings use **single quotes**: double quotes are treated as column names in Postgres/MySQL
- Production habit: **always list column names** — a bare `VALUES` misaligns the moment a column is added
- Insert partial columns: `INSERT INTO Movies (title, director) VALUES ('Toy Story', 'John Lasseter');`, the rest take defaults/NULL

---

## 2. JOIN: INNER / LEFT / self-join / CROSS JOIN

### 2.1 INNER vs LEFT

```sql
-- INNER: only rows matching on both sides survive (Wang Wu has no orders → gone)
SELECT c.name, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;

-- LEFT JOIN: left table fully kept, unmatched right side filled with NULL (Wang Wu survives, amount=NULL)
SELECT c.name, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
```

- `LEFT JOIN` is the workhorse (95% of the time); `RIGHT JOIN` is almost never seen; `FULL JOIN` keeps both sides

### 2.2 ON vs WHERE: the easiest place to go wrong in LEFT JOIN

**❌ Why the WHERE version is wrong**:

```sql
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.amount > 100;
```

LEFT JOIN first produces Wang Wu's NULL row, then WHERE evaluates `NULL > 100` → NULL (not true) → the row is dropped. The LEFT JOIN was pointless — it's now equivalent to INNER JOIN.

**✅ Why the ON version is right**:

```sql
LEFT JOIN orders o ON c.id = o.customer_id AND o.amount > 100;
```

ON controls "matching eligibility": right-side rows that fail the condition are treated as nonexistent, left rows are kept with NULLs on the right. No WHERE to kill the NULL rows.

**Rule**: in a LEFT JOIN, conditions on the right table go in `ON`, conditions on the left table go in `WHERE`.

**Boundary case** (Wang Wu has a $50 order):

- WHERE version: `50 > 100` is false → Wang Wu disappears
- ON version: the $50 order isn't eligible for matching → Wang Wu is kept, amount shows **NULL (not 50)**
- The NULL in the ON version means "no order over $100", not "no orders at all"

### 2.3 Orphan records and foreign keys

Zhao Liu has an order (customer_id=4) but isn't in the customers table → neither INNER nor LEFT JOIN shows that order (orphan right rows are dropped); RIGHT/FULL JOIN show it (name=NULL).

Production databases shouldn't have orphans — prevent them with foreign keys:

```sql
customer_id INTEGER NOT NULL REFERENCES customers(id)
```

The database simply rejects inserting a nonexistent customer_id — dirty data never gets in, so JOINs don't have to worry about it.

### 2.4 Self-join: two "aliases" of the same table

A self-join must use aliases, or you can't tell who is who.

**1661: pairing start/end to get average processing time**

Table Activity(machine_id, process_id, activity_type, timestamp); each process has a start row and an end row:

```sql
SELECT a1.machine_id,
       ROUND(AVG(a2.timestamp - a1.timestamp), 3) AS processing_time
FROM Activity a1
JOIN Activity a2 ON a1.machine_id = a2.machine_id
               AND a1.process_id = a2.process_id
               AND a1.activity_type = 'start'
               AND a2.activity_type = 'end'
GROUP BY a1.machine_id;
```

- All four ON conditions are required: without activity_type, start rows would pair with start rows
- The classic pitfall: forgetting the activity_type condition. Remember: self-join pairing = finding the condition that "turns two rows into one pair"

**181: employees earning more than their managers**

Table Employee(id, name, salary, managerId):

| id | name | salary | managerId |
|-----|-------|--------|-----------|
| 1 | Joe | 70000 | 3 |
| 2 | Henry | 80000 | 4 |
| 3 | Sam | 60000 | NULL |
| 4 | Max | 90000 | NULL |

```sql
SELECT e1.name AS Employee
FROM Employee e1
JOIN Employee e2 ON e1.managerId = e2.id
WHERE e1.salary > e2.salary;
-- Joe(70000) vs Sam(60000) ✅; Henry(80000) vs Max(90000) ❌ → answer: Joe
```

Key point: `ON e1.managerId = e2.id` is the "employee → manager" mapping; rows with no manager (managerId NULL) can't join and are automatically excluded.

**1731: each manager's report count** (same table, different question):

```sql
SELECT e2.name AS manager, COUNT(*) AS reports_count
FROM Employee e1
JOIN Employee e2 ON e1.managerId = e2.id
GROUP BY e2.id, e2.name;
```

This time e1 is the reports, e2 is the manager; `GROUP BY` the manager and count.

### 2.5 CROSS JOIN: cartesian product to build full combinations (1280)

Tables: Students (1 Alice, 2 Bob); Subjects (Math, Physics, Programming); Examinations: (1,Math), (1,Math), (2,Programming). Requirement: **one row per student × subject**, showing 0 for never-taken:

```sql
SELECT s.student_id, s.student_name, sub.subject_name,
       COUNT(e.subject_name) AS attended_exams
FROM Students s
CROSS JOIN Subjects sub
LEFT JOIN Examinations e
  ON e.student_id = s.student_id AND e.subject_name = sub.subject_name
GROUP BY s.student_id, s.student_name, sub.subject_name
ORDER BY s.student_id, sub.subject_name;
```

1. `CROSS JOIN` builds all 2×3=6 combinations
2. LEFT JOIN the exam records: Alice-Math matches 2 rows, Alice-Physics matches 0 (e.subject_name is NULL)
3. `COUNT(e.subject_name)` only counts non-NULL → Alice-Math=2, Alice-Physics=**0** ✅

**Pitfall**: here you must `COUNT(column name)`, never `COUNT(*)` — `COUNT(*)` counts the NULL rows too, and never-taken subjects would show 1. This CROSS JOIN + LEFT JOIN pairing is a fixed combo for these problems.

---

## 3. Subqueries in three positions + UNION

### 3.1 Three positions of subqueries

**Position 1: in WHERE as a condition**

```sql
SELECT name FROM emp
WHERE salary > (SELECT AVG(salary) FROM emp);
```

Walk through: inner `AVG(salary)` = (9000+5000+8000+6000+10000)/5 = **7800**; the outer becomes `WHERE salary > 7800`: Zhang San 9000 ✅, Li Si 5000 ❌, Wang Wu 8000 ✅, Zhao Liu 6000 ❌, Qian Qi 10000 ✅ → Zhang San, Wang Wu, Qian Qi.

Key point: the inner query must return **a single row and single column** (a scalar), otherwise it errors. The inner runs once first, its result is substituted into the outer.

**Position 2: in FROM as a temp table**

```sql
SELECT dept, name, salary
FROM (SELECT name, dept, salary,
             ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn
      FROM emp) t
WHERE rn = 1;
```

The inner query first ranks within each department (IT: Zhang San rn=1, Li Si rn=2; Sales: Wang Wu rn=1, Zhao Liu rn=2; HR: Qian Qi rn=1); the outer treats the inner as temp table `t`, and `WHERE rn = 1` takes the top earner per department: Zhang San, Wang Wu, Qian Qi.

Key point: a subquery in FROM **must have an alias** — missing it is a straight syntax error.

**Position 3: in SELECT as a column (correlated subquery, use with caution)**

```sql
SELECT name, dept,
       (SELECT COUNT(*) FROM emp e2 WHERE e2.dept = e1.dept) AS dept_cnt
FROM emp e1;
-- Zhang San IT 2, Li Si IT 2, Wang Wu Sales 2...
```

**Pitfall**: this is a **correlated subquery** — the inner references the outer's `e1.dept`, so it executes **once per row**. 5 rows in emp → 5 executions; 1M rows → 1M executions, a performance disaster. Rewrite in practice as a window function, one scan:

```sql
SELECT name, dept, COUNT(*) OVER (PARTITION BY dept) AS dept_cnt
FROM emp;
```

Memory aid: WHERE subqueries "compute the condition first"; FROM subqueries "build a temp table first"; SELECT subqueries "query row by row" — avoid when you can.

**IN vs EXISTS primer**:

```sql
-- IN: a value list or a small result set
SELECT name FROM emp WHERE dept IN ('IT', 'HR');  -- Zhang San, Li Si, Qian Qi

-- EXISTS: correlated subquery, only asks "does it exist", stops at the first hit — faster on big tables
SELECT name FROM emp e
WHERE EXISTS (SELECT 1 FROM emp s WHERE s.manager_id = e.id);
```

IN goes with small lists; EXISTS only asks "is there any". **Pitfall**: if the `NOT IN` subquery contains NULL, the whole result is empty! Use `NOT EXISTS` instead (see Sections 6 and 7).

### 3.2 UNION / UNION ALL: stacking rows

```sql
SELECT name FROM emp WHERE dept = 'IT'
UNION ALL
SELECT name FROM emp WHERE dept = 'Sales';
-- Zhang San, Li Si, Wang Wu, Zhao Liu (4 rows stacked)
```

**Difference from JOIN**: UNION **adds rows** (vertical stacking), JOIN **adds columns** (horizontal stacking).

| | UNION | UNION ALL |
|---|---|---|
| Dedup | yes | no |
| Speed | slow (sort + dedup) | fast |
| Default choice | — | **use this by default** |

Three rules:

1. Both SELECTs must have the **same number of columns**, with matching types
2. Column names follow the **first** SELECT
3. Unless you explicitly need dedup, always use `UNION ALL` — dedup is extra cost

---

## 4. Aggregation: DISTINCT, COUNT, GROUP BY, HAVING

### 4.1 DISTINCT: whole-row dedup

```sql
SELECT DISTINCT city FROM customers;        -- single-column dedup
SELECT DISTINCT city, name FROM customers;  -- dedup on (city, name) combinations
```

- `DISTINCT a, b` dedups the **combination**, not a and b separately
- `SELECT a, DISTINCT b` is a **syntax error** — DISTINCT is a whole-row modifier and can only follow SELECT
- The parentheses in `DISTINCT(a)` do nothing — dedup is always whole-row

### 4.2 Four COUNT forms

| Form | Meaning |
|---|---|
| `COUNT(*)` | row count (NULL rows included) |
| `COUNT(city)` | rows where city is non-NULL |
| `COUNT(DISTINCT city)` | how many distinct cities (NULL not counted) |
| `COUNT(DISTINCT city, name)` | MySQL: distinct combinations (PG writes it `COUNT(DISTINCT (city, name))`) |

Three pitfalls:

1. `COUNT(email)` misses rows with no email filled in — use `COUNT(*)` when you want a count
2. NULL is not counted in `COUNT(DISTINCT city)`
3. NULLs form their own group in `GROUP BY` (see 4.3)

**"How many distinct b per a" template** (same mold as LeetCode 1693):

```sql
-- how many distinct titles per department
SELECT dept, COUNT(DISTINCT title) AS title_count
FROM emp GROUP BY dept;
```

### 4.3 GROUP BY and NULL

```sql
SELECT city, COUNT(*) FROM customers GROUP BY city;
-- Beijing 2, Shanghai 1, NULL 1 (Zhao Liu in his own group)
```

**GROUP BY is the one place that treats NULLs as equal**:

| Scenario | NULL behavior |
|---|---|
| `WHERE city = NULL` | always false |
| `WHERE city != 'Beijing'` | NULL rows dropped |
| `GROUP BY city` | all NULLs huddle into one group |
| `COUNT(city)` / `COUNT(DISTINCT city)` | NULLs skipped |

Don't want the NULL group: `WHERE city IS NOT NULL` before GROUP BY.

### 4.4 HAVING: the WHERE after grouping

HAVING is "WHERE after grouping" and **only takes aggregate conditions** — `HAVING salary > 5000` errors out. Execution order: WHERE (filter rows before grouping) → GROUP BY → HAVING (filter groups after grouping).

**Primer (596, 182)** — grind these two first to build the feel:

```sql
-- 596: classes with more than 5 students
SELECT class FROM Courses
GROUP BY class
HAVING COUNT(*) >= 5;

-- 182: find duplicate emails
SELECT email FROM Person
GROUP BY email
HAVING COUNT(*) > 1;
-- GROUP BY email huddles identical emails together; HAVING COUNT(*) > 1 keeps groups with >1 member
```

**Combined use (1070: first-year sales per product)**

Table Sales:

| sale_id | product_id | year | quantity | price |
|---------|------------|------|----------|-------|
| 1 | 100 | 2008 | 10 | 5000 |
| 2 | 100 | 2009 | 12 | 5000 |
| 3 | 200 | 2011 | 15 | 9000 |

Answer: product 100's first year is 2008 (10 units), product 200's first year is 2011 (15 units).

```sql
SELECT product_id, year AS first_year, quantity, price
FROM Sales
WHERE (product_id, year) IN (
    SELECT product_id, MIN(year) FROM Sales GROUP BY product_id
);
```

Walk through: the subquery `GROUP BY product_id` + `MIN(year)` → (100, 2008), (200, 2011); the outer `WHERE (product_id, year) IN (...)` uses a **row constructor** to match two columns at once → id=1 ✅, id=2 ❌, id=3 ✅.

Window-function version (same template as 184):

```sql
SELECT product_id, year AS first_year, quantity, price
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY year) AS rn
      FROM Sales) t
WHERE rn = 1;
```

Difference from the primers: 1070 is "find each group's minimum year first, then fetch the full row", while 596/182 are "group + HAVING gives the answer directly".

---

## 5. Window functions

**One line**: GROUP BY squeezes many rows into one; window functions don't squeeze — every row stays, and each row can see values computed from "neighboring rows".

```sql
SELECT name, dept, salary,
       AVG(salary) OVER (PARTITION BY dept) AS dept_avg
FROM emp;
```

**Syntax skeleton**:

```sql
function_name(...) OVER (
    PARTITION BY column      -- grouping (optional)
    ORDER BY column          -- ordering within group (required for ranking)
    ROWS BETWEEN ...         -- window frame (optional)
)
```

### 5.1 The three ranking brothers (most frequent in interviews)

| Function | On ties | Example |
|---|---|---|
| ROW_NUMBER() | no ties honored | 1,2,3 |
| RANK() | skips numbers | 1,1,3 |
| DENSE_RANK() | no skipping | 1,1,2 |

```sql
SELECT name, dept, salary,
       ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn,
       RANK()       OVER (PARTITION BY dept ORDER BY salary DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS dense_rnk
FROM emp;
```

**TopN per group template (LeetCode 184 — memorize it)**:

```sql
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn
    FROM emp
) t WHERE rn <= 3;
```

### 5.2 LAG / LEAD: look at the previous / next row

```sql
-- month-over-month: this month vs last month
SELECT month, amount,
       LAG(amount, 1) OVER (ORDER BY month) AS prev_month,
       amount - LAG(amount, 1) OVER (ORDER BY month) AS diff
FROM sales;
```

Pitfall: `LAG(temperature)` takes the "previous row" — when a day is missing, the previous row could be 3 days ago. "Previous row" is not "previous day" (LeetCode 197, see 15.2).

### 5.3 Frame: which rows the window covers

| Form | Meaning |
|---|---|
| `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | accumulate from the start to the current row (default, running total) |
| `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | current row + 2 previous (3-row sliding window) |
| `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` | 1 before + current + 1 after |

ROWS is enough for 99% of cases. `ROWS` slides by row count, `RANGE` slides by value (behaves differently when dates are missing — an interview favorite).

### 5.4 FIRST_VALUE / LAST_VALUE / NTILE

```sql
SELECT name, dept, salary,
       FIRST_VALUE(name) OVER (PARTITION BY dept ORDER BY salary DESC) AS top_earner,
       FIRST_VALUE(salary) OVER (PARTITION BY dept ORDER BY salary DESC) - salary AS gap_to_top,
       NTILE(4) OVER (ORDER BY salary DESC) AS quartile
FROM emp;
```

- Classic pitfall: LAST_VALUE's default frame ends at the current row; to get the group's last row use `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`
- NTILE(n): split into n buckets evenly (salary quartiles, user tiers)

### 5.5 Killer technique: N consecutive login days (interview staple — memorize)

```sql
SELECT DISTINCT user_id
FROM (
    SELECT user_id, login_date,
           login_date - ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date)::int AS grp
    FROM logins
) t
GROUP BY user_id, grp
HAVING COUNT(*) >= 3;
```

Consecutive dates minus ROW_NUMBER give the same grp for consecutive days — turning "consecutiveness" into "group and count".

### 5.6 Why WHERE can't use window functions

Execution order is FROM → WHERE → SELECT; window functions are computed at the SELECT stage — so you must wrap them in a subquery.

### 5.7 Learning sites

- Concepts: Mode SQL Tutorial (mode.com/sql-tutorial/sql-window-functions) — free, interactive exercises
- PG-specific: PostgreSQLTutorial (postgresqltutorial.com/postgresql-window-function) — examples runnable in psql
- SQLBolt has no window-function chapter; don't look for it there

---

## 6. NULL three-valued logic deep dive

### 6.1 The symptom: NOT IN with NULL wipes everything out

```sql
-- suppose the subquery returns ('IT', 'HR', NULL)
SELECT name FROM emp WHERE dept NOT IN ('IT', 'HR', NULL);
-- result: empty! Not a single row
```

### 6.2 Take it apart: what NOT IN is really asking

`NOT IN` is shorthand; the database actually executes:

```sql
WHERE dept != 'IT' AND dept != 'HR' AND dept != NULL
```

Note the last one: `dept != NULL` — comparing a concrete value against NULL.

### 6.3 Walk through row by row — watch Wang Wu's row

**Zhang San (dept='IT')**: `'IT' != 'IT'` → FALSE; `FALSE AND …` → FALSE, out immediately. Matches intuition.

**Wang Wu (dept='Sales')** — the important one:

- `'Sales' != 'IT'` → TRUE
- `'Sales' != 'HR'` → TRUE
- `'Sales' != NULL` → **NULL** ("does Sales equal an unknown value?" — unknown)

`TRUE AND TRUE AND NULL` → **NULL**. WHERE only accepts TRUE rows; NULL is not TRUE, so Wang Wu is filtered out.

Zhao Liu, Li Si, Qian Qi likewise — every row hits `!= NULL`, every result is NULL, total wipeout.

**Analogy**: like the X state in Verilog — `X == 1` gives X; in SQL, comparing anything with NULL gives NULL.

### 6.4 SQL three-valued logic truth table

SQL isn't true-or-false; it has three values: TRUE / FALSE / NULL (unknown).

```
AND:
TRUE AND NULL → NULL  (true AND unknown → still unknown)
FALSE AND NULL → FALSE (false AND unknown → false)

OR:
TRUE OR NULL → TRUE   (true OR unknown → true)
FALSE OR NULL → NULL  (false OR unknown → unknown)
```

### 6.5 Why IN is fine but NOT IN crashes

```sql
SELECT name FROM emp WHERE dept IN ('IT', 'HR', NULL);
-- result: Zhang San, Li Si, Qian Qi ✅ normal
```

- Wang Wu: `'Sales'='IT' OR 'Sales'='HR' OR 'Sales'=NULL` → `FALSE OR FALSE OR NULL` → **NULL** → filtered (exactly what we want)
- Zhang San: `TRUE OR FALSE OR NULL` → **TRUE** → kept ✅

`IN` uses OR, so TRUE can "short-circuit" past NULL; `NOT IN` uses AND, so NULL "poisons" TRUE. **The asymmetry is right here**.

### 6.6 Why NOT EXISTS is safe (row-by-row trace)

```sql
SELECT name FROM emp e1
WHERE NOT EXISTS (SELECT 1 FROM emp e2
                  WHERE e2.dept = e1.dept AND e2.dept IN ('IT','HR'));
```

e1 and e2 are two "aliases" of the same table. The outer walks e1 row by row; for each row, the inner runs once with that row's dept value. `SELECT 1` means "don't care about content, only whether any row exists".

- **e1 = Zhang San (IT)**: inner `WHERE e2.dept='IT' AND e2.dept IN ('IT','HR')` → Zhang San, Li Si hit → 2 rows → NOT EXISTS=FALSE → filtered ✅
- **e1 = Li Si (IT)**: same → filtered ✅
- **e1 = Wang Wu (Sales)**: inner `WHERE e2.dept='Sales' AND e2.dept IN ('IT','HR')` → Wang Wu passes the first condition ✅ but fails the second ❌ → 0 rows → NOT EXISTS=TRUE → **kept** ✅
- **e1 = Zhao Liu (Sales)**: same as Wang Wu → kept ✅
- **e1 = Qian Qi (HR)**: Qian Qi hits himself → filtered ✅

Result: **Wang Wu, Zhao Liu** ✅

**Why NULL can't poison it**:

- `NOT IN`: NULL sits in the **outer WHERE**'s AND chain; every row must pass it, one touch turns NULL, total wipeout
- `NOT EXISTS`: NULL only appears in some **inner** row's comparison (`NULL = 'Sales'` → NULL → that row doesn't match). But EXISTS only asks "did any row match" — other normal rows still match. The NULL row is simply "not counted"; it can't poison the outer verdict

**Analogy**: `NOT IN` is asking everyone "you're not one of these three people (one wears a mask), right?" — nobody dares guarantee; `NOT EXISTS` asks "is there anyone in the room matching the description?" — the masked one doesn't match the description, gets skipped, doesn't affect the answer.

### 6.7 In practice: where this bites

**Scenario 1: reconciliation / finding diffs (DBA daily)**

```sql
-- find orders that were placed but never paid
SELECT order_id FROM orders
WHERE order_id NOT IN (SELECT order_id FROM payments);
```

One NULL sneaks into `payments.order_id` (test data / dirty data / ETL bug — all too common in production), and the query returns **empty** — finance thinks everything is collected while a pile is unpaid. **Production incident**. Fix: `NOT EXISTS` or `LEFT JOIN ... IS NULL`.

**Scenario 2: RAG dedup on insert (AI data pipeline)** — see 7.1.

**Scenario 3: interview classic (LeetCode 183: customers who never order)**

```sql
-- Customers(id, name), Orders(id, customerId)
-- Form 1 NOT IN: breaks if customerId has NULL
-- Form 2 LEFT JOIN + IS NULL: safe
SELECT c.name FROM Customers c
LEFT JOIN Orders o ON c.id = o.customerId WHERE o.id IS NULL;
-- Form 3 NOT EXISTS: safest, what the interviewer wants to hear
SELECT name FROM Customers c
WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.customerId = c.id);
```

Interviewers love the follow-up: "what's the difference between the three forms? Which one on large data?" — `NOT IN` fears NULL; `NOT EXISTS` has the cleanest semantics and the optimizer usually handles it well on big tables; `LEFT JOIN` is intuitive but mind the dedup.

### 6.8 One-paragraph summary

| Point | Content |
|---|---|
| NULL comparison | comparing anything with NULL → NULL (like Verilog X state) |
| WHERE convergence | only TRUE is accepted; NULL rows are dropped |
| NOT IN essence | an AND chain of `!=`; NULL sits in the outer layer poisoning every row |
| Why IN is fine | OR chain; TRUE short-circuits past NULL |
| NOT EXISTS essence | only asks "rows or no rows"; NULL in the inner only affects single-row matching |
| Production iron rule | "has A, lacks B" queries always use NOT EXISTS or LEFT JOIN…IS NULL, never NOT IN |
| First rule of data work | always assume columns contain NULL |

**Mnemonic**: IN goes with small lists; EXISTS asks "is there any"; **see NULL with NOT IN, switch to NOT EXISTS**.

---

## 7. Three anti-join patterns

An "anti-join" = "has A, lacks B" queries. Three forms, in increasing safety.

### 7.1 RAG dedup on insert: NOT EXISTS version (row-by-row trace)

Scenario: only insert new chunks that "aren't in the vector store yet".

new_chunks (just parsed):

| chunk_id | doc_name |
|---|---|
| A001 | manual_v3.pdf#12 (already inserted) |
| A003 | faq.pdf#1 (new doc) |
| NULL | empty doc, parse failed |

embedded_chunks (already in the vector store):

| chunk_id |
|---|
| A001 |
| NULL | ← a previous dirty write also stored NULL |

**❌ Wrong version**:

```sql
SELECT chunk_id FROM new_chunks
WHERE chunk_id NOT IN (SELECT chunk_id FROM embedded_chunks);
```

The subquery returns `('A001', NULL)`; walk each row through `chunk_id != 'A001' AND chunk_id != NULL`:

- A001: `FALSE AND …` → filtered (correct, it should be)
- A003: `TRUE AND NULL` → NULL → filtered ❌
- NULL: `NULL AND …` → NULL → filtered

Result: empty. New doc A003 was never inserted but is judged "already inserted" — silently lost. Pipeline all green, no errors.

**✅ Correct version**:

```sql
SELECT chunk_id FROM new_chunks n
WHERE NOT EXISTS (SELECT 1 FROM embedded_chunks e WHERE e.chunk_id = n.chunk_id);
```

- A001: inner hits 1 row → filtered ✅ (it really is inserted)
- A003: inner hits 0 rows → kept ✅
- NULL: `e.chunk_id = NULL` is always NULL, inner hits 0 rows → kept. Whether an empty chunk should be inserted is decided explicitly in the cleaning stage with `WHERE chunk_id IS NOT NULL` — the dedup logic shouldn't quietly "eat" good data as a side effect

**Why it's hell to debug**: the insert job succeeds daily, monitoring all green, but Q&A over new docs never works. You'll first suspect the embedding model, chunk size, top_k — all innocent; the real killer is one line of SQL in the dedup. And the root cause is just a NULL that snuck into embedded_chunks.

### 7.2 LEFT JOIN version

```sql
SELECT n.chunk_id, n.doc_name
FROM new_chunks n
LEFT JOIN embedded_chunks e
  ON e.chunk_id = n.chunk_id
WHERE e.chunk_id IS NULL;
```

Walk the same two tables row by row:

- A001: `ON` condition hits, e side has values → `WHERE e.chunk_id IS NULL` fails → filtered ✅
- A003: `ON` finds no match, e side all NULL → kept ✅
- NULL: `NULL = NULL` gives NULL, `ON` never holds → e side all NULL → kept (same behavior as NOT EXISTS)

Result: A003, NULL.

**The essential difference**: `=` in `ON` meeting NULL is just "match failed" — the row survives (e side padded with NULL); `!= NULL` in `NOT IN` turns the whole row NULL and throws it away. One keeps, one discards — dirty NULL's damage is worlds apart.

Note `e.chunk_id IS NULL` must be in WHERE — the essence of LEFT JOIN is "keep the whole left table first, then use the right side's NULL-ness to judge whether anything matched".

### 7.3 The "has A, lacks B" template (LeetCode 1581, 1378)

```sql
-- 1581: each customer's count of "visited but never transacted"
SELECT customer_id, COUNT(*) AS count_no_trans
FROM Visits v
LEFT JOIN Transactions t ON v.visit_id = t.visit_id
WHERE t.transaction_id IS NULL
GROUP BY customer_id;

-- 1378: each employee's unique_id, NULL if missing
SELECT u.unique_id, e.name
FROM Employees e
LEFT JOIN EmployeeUNI u ON e.id = u.id;
-- Pitfall: INNER JOIN would drop employees with no unique_id. "Show even when missing" means LEFT JOIN
```

Remember: "has A, lacks B" is always LEFT JOIN + IS NULL — at least 5 LeetCode problems use this mold.

---

## 8. WITH (CTE)

WITH gives a subquery a name, valid for this query only, gone after. Think of it as naming an intermediate wire in Verilog and referencing it later, instead of nesting one long combinational expression in a single line.

### 8.1 Primer: single CTE

```sql
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn
    FROM emp
)
SELECT * FROM ranked WHERE rn <= 3;
```

Step 1 computes the `ranked` "temp table" (ranking by salary within each department):

| name | dept | salary | rn |
|---|---|---|---|
| Zhang San | IT | 9000 | 1 |
| Li Si | IT | 5000 | 2 |
| Wang Wu | Sales | 8000 | 1 |
| Zhao Liu | Sales | 6000 | 2 |
| Qian Qi | HR | 10000 | 1 |

Step 2 treats it as an ordinary table: `WHERE rn <= 3`. Each department has at most 2 people here, so all 5 rows survive — in effect "top 3 earners per department". Change it to `rn = 1` and you get the top earner per department: Zhang San, Wang Wu, Qian Qi.

### 8.2 Multiple CTEs: comma-separated, chained references

```sql
WITH high_earners AS (
    SELECT name, dept, salary FROM emp WHERE salary >= 8000
),
ranked AS (
    SELECT name, dept, salary,
           DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS rnk
    FROM high_earners
)
SELECT * FROM ranked WHERE rnk = 1;
```

- `high_earners`: Zhang San 9000, Wang Wu 8000, Qian Qi 10000 (filter first)
- `ranked`: references `high_earners`, ranks within departments
- Main query takes `rnk = 1` → Zhang San, Wang Wu, Qian Qi

Note: WITH is written once, CTEs separated by commas; a later CTE can reference earlier ones, never the reverse — order is dependency.

### 8.3 Compared with nested subqueries

```sql
SELECT name, dept, salary FROM (
    SELECT *, DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS rnk
    FROM (SELECT * FROM emp WHERE salary >= 8000) t1
) t2 WHERE rnk = 1;
```

Logically equivalent, but the reading order is reversed: nested queries must be peeled from the innermost out; WITH reads top-down. Two levels of nesting is manageable; beyond three it's unreadable.

### 8.4 Three pitfalls

1. One CTE can be referenced multiple times; a subquery reused twice must be copy-pasted twice — the second real benefit of WITH beyond readability
2. Recursive CTEs need the `RECURSIVE` keyword, supported in Postgres/MySQL 8+
3. Performance note: before Postgres 12, a CTE is an "optimization fence" — always materialized before continuing; 12+ the planner may inline it. EXPLAIN will tell you the truth when tuning

One line: WITH = name + stepwise, the cure for nested-subquery hell.

### 8.5 Recursive CTE (1767: task-subtask pairs never executed)

Table Tasks(task_id, subtasks_count) — each task has N subtasks numbered 1~N; Executed(task_id, subtask_id) — executed subtasks. Find the **never executed** (task_id, subtask_id) pairs.

Tasks:

| task_id | subtasks_count |
|---------|----------------|
| 1 | 3 |
| 2 | 2 |

Executed:

| task_id | subtask_id |
|---------|------------|
| 1 | 1 |
| 1 | 3 |
| 2 | 2 |

Answer: (1,2), (2,1).

```sql
WITH RECURSIVE sub AS (
    -- anchor: subtask 1 of each task
    SELECT task_id, 1 AS subtask_id, subtasks_count
    FROM Tasks
    UNION ALL
    -- recurse: previous +1, until reaching subtasks_count
    SELECT task_id, subtask_id + 1, subtasks_count
    FROM sub
    WHERE subtask_id < subtasks_count
)
SELECT s.task_id, s.subtask_id
FROM sub s
LEFT JOIN Executed e
  ON e.task_id = s.task_id AND e.subtask_id = s.subtask_id
WHERE e.task_id IS NULL;
```

Walk through (recursion is like a snowball):

1. Anchor produces: (1,1), (2,1)
2. Round 1: (1,1)→(1,2) ✅ (1<3); (2,1)→(2,2) ✅ (1<2)
3. Round 2: (1,2)→(1,3) ✅ (2<3); (2,2): 2<2 ❌, stops
4. Round 3: (1,3): 3<3 ❌, all stop. Final set: (1,1), (1,2), (1,3), (2,1), (2,2)
5. LEFT JOIN Executed, `WHERE e.task_id IS NULL` anti-selects the unexecuted → (1,2), (2,1) ✅

Key points:

- `WITH RECURSIVE` references itself and must have a **termination condition** (here `subtask_id < subtasks_count`), otherwise infinite recursion
- 1645 uses the same trick: recurse to generate a consecutive month sequence, then LEFT JOIN the business table
- **Analogy**: like counter reset logic — the anchor is the reset value, recursion is +1 every clock, the termination condition is the count-full overflow

---

## 9. CASE WHEN / COALESCE / conditional aggregation

### 9.1 CASE WHEN primer: the if-else of SQL

Conditional counting = CASE WHEN + SUM/COUNT — one row becomes many columns:

```sql
-- headcount per score band
SELECT
    SUM(CASE WHEN score >= 90 THEN 1 ELSE 0 END) AS excellent,
    SUM(CASE WHEN score >= 60 AND score < 90 THEN 1 ELSE 0 END) AS pass,
    SUM(CASE WHEN score < 60 THEN 1 ELSE 0 END) AS fail
FROM students;
```

LeetCode 1211 and 1179 are both this.

### 9.2 CASE WHEN: salary band statistics

```sql
SELECT
    CASE WHEN salary >= 9000 THEN 'high'
         WHEN salary >= 6000 THEN 'mid'
         ELSE 'low' END AS level,
    COUNT(*) AS cnt
FROM emp
GROUP BY level;
```

Walk through: CASE WHEN matches top-down, stops at the first hit — Zhang San 9000 → high; Li Si 5000 → low; Wang Wu 8000 → mid; Zhao Liu 6000 → mid; Qian Qi 10000 → high.

| level | cnt |
|-------|-----|
| high | 2 |
| mid | 2 |
| low | 1 |

Key point: `WHEN` order matters — write the strict one first (>=9000 before >=6000), or 9000 gets intercepted by >=6000. `ELSE` is the fallback; without it, no-match returns NULL.

### 9.3 Conditional aggregation: the universal percentage formula

**Conditional percentage (1211)**: table Queries(query_name, result, position, rating); for each query_name find quality and poor_query_percentage, rounded to 2 decimals.

Table Queries (query_name='dog'):

| query_name | result | position | rating |
|------------|--------------------|----------|--------|
| dog | golden retriever | 1 | 5 |
| dog | german shepherd | 2 | 5 |
| dog | old english sheepdog| 3 | 1 |

- quality = AVG(rating/position) = (5/1 + 5/2 + 1/3)/3 ≈ 2.61
- poor_query_percentage: only row 3 has rating<3 → 1/3 ≈ 33.33%

```sql
SELECT query_name,
       ROUND(AVG(rating / position), 2) AS quality,
       ROUND(AVG(CASE WHEN rating < 3 THEN 1 ELSE 0 END) * 100, 2)
           AS poor_query_percentage
FROM Queries
GROUP BY query_name;
```

The core trick: `CASE WHEN` turns each row into 1/0 (ratings 5→0, 5→0, 1→1); `AVG(0,0,1)` = 1/3. **`AVG(CASE WHEN condition THEN 1 ELSE 0 END)` = the share satisfying the condition** — the universal formula for all "percentage" problems.

**1633, same mold** (denominator counts all users via subquery):

```sql
SELECT contest_id,
       ROUND(COUNT(DISTINCT user_id) * 100 /
             (SELECT COUNT(*) FROM Users), 2) AS percentage
FROM Register
GROUP BY contest_id
ORDER BY percentage DESC, contest_id;
-- ORDER BY percentage DESC, contest_id: sort by percentage descending first, then id ascending for ties — multi-column sort, comma-separated with priority
```

**Conditional sum** (CASE WHEN's second use, see 11.5's 1193): counting is `THEN 1 ELSE 0`, summing is `THEN amount ELSE 0`.

### 9.4 COALESCE: NULL fallback

`COALESCE(a, b, c)` returns the first non-NULL value, scanning left to right.

```sql
-- display fallback: phone → email → 'no contact info', cascading
SELECT name, COALESCE(phone, email, 'no contact info') AS contact
FROM emp;
-- Zhang San: 1380001 / Li Si: lisi@x.com (phone is NULL, falls through to email)
-- Wang Wu: 1380003 / Zhao Liu: 'no contact info' (both NULL) / Qian Qi: 1380005

-- arithmetic fallback: NULL poisons any arithmetic, so COALESCE first
SELECT name, salary + COALESCE(bonus, 0) AS total
FROM emp;
-- Li Si: 5000 + 0 = 5000 (bonus is NULL; without the guard, total becomes NULL)
-- Qian Qi: 10000 + 0 = 10000
```

Key point: any number with NULL in arithmetic gives NULL, so **COALESCE NULLs to 0 or a default before computing**. LEFT JOIN + COALESCE is a fixed pair (see 7.2 and 11.9's 1421).

---

## 10. Date functions

### 10.1 Primer (MySQL version, for LeetCode)

```sql
DATEDIFF('2024-01-10', '2024-01-01')       -- 9 (later minus earlier, day difference)
DATE_ADD('2024-01-01', INTERVAL 1 MONTH)    -- 2024-02-01
YEAR('2024-05-20')                          -- 2024
MONTH('2024-05-20')                         -- 5
DATE_FORMAT('2024-05-20', '%Y-%m')          -- '2024-05' (the group-by-month tool)
```

PG equivalents (used after W1D3): `EXTRACT(YEAR FROM d)`, `d + INTERVAL '1 month'`.

### 10.2 Deep dive

**DATEDIFF: day difference** — counts **how many date boundaries are crossed**, not 24-hour periods.

```sql
DATEDIFF('2024-01-10', '2024-01-01')  -- 9
```

Classic pitfall: `DATEDIFF('2024-01-02 00:00:01', '2024-01-01 23:59:59')` = 1, though only 2 seconds apart. Reversed order gives a negative.

Postgres version: `'2024-01-10'::date - '2024-01-01'::date` → 9 (an integer directly). You've actually used this — 197 Rising Temperature's `DATEDIFF(w1.recordDate, w2.recordDate) = 1` is exactly it.

**DATE_ADD: date arithmetic, auto-clamped at month end**:

```sql
DATE_ADD('2024-01-31', INTERVAL 1 MONTH)  -- 2024-02-29
```

2024 is a leap year; February has only 29 days. Jan 31 plus one month doesn't become the illegal "Feb 31" — it's clamped to Feb 29. Subtract with `DATE_SUB` or `INTERVAL -1 MONTH`.

Postgres version: `'2024-01-31'::date + INTERVAL '1 month'` → also 2024-02-29, same behavior.

**DATE_FORMAT: formatting, `'%Y-%m'` is the group-by-month tool**:

```sql
SELECT DATE_FORMAT(hire_date, '%Y-%m') AS hire_month, COUNT(*) AS cnt
FROM emp
GROUP BY hire_month;
-- 2024-01: 2 (Zhang San, Li Si)  2024-02: 2 (Wang Wu, Zhao Liu)  2024-03: 1 (Qian Qi)
```

`DATE_FORMAT` compresses a date into a string like `'2024-01'`; people in the same month share the same string → they huddle together under GROUP BY.

Postgres version: `TO_CHAR(hire_date, 'YYYY-MM')`, or `DATE_TRUNC('month', hire_date)` (returns the 1st of the month at midnight — friendlier for sorting).

### 10.3 Last-N-days filtering: two interpretations

Using an orders table, assuming today is 2024-01-10:

| order_id | created_at |
|---|---|
| 1 | 2024-01-09 15:00 |
| 2 | 2024-01-03 10:00 |
| 3 | 2024-01-02 23:00 |

```sql
-- MySQL
SELECT * FROM orders
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY);

-- Postgres
SELECT * FROM orders
WHERE created_at >= NOW() - INTERVAL '7 days';
```

`NOW() - 7 days` = 2024-01-03 at this moment: order 1 (01-09) is after the line ✅; order 2 (01-03 10:00) is on the line, `>=` includes the boundary ✅; order 3 (01-02 23:00) is before the line ❌. Result: orders 1, 2.

Two practical details:

1. **Keep the column naked**: writing `WHERE DATE(created_at) >= ...` repeats the slow-query mistake — a function on the column kills the index. Put the range condition directly on the naked column (see 12.1).
2. **"Last 7 days" has two interpretations**: above is "roll back 168 hours" (exact timestamps); for "7 calendar days including today", use `CURDATE()` instead of `NOW()`, and change the interval to 6 days (today counts as one):

```sql
-- MySQL: 7 calendar days including today
WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY);
-- Postgres
WHERE created_at >= CURRENT_DATE - INTERVAL '6 days';
```

Mnemonic: NOW() for exact lookback, CURDATE() for day-granularity stats, and never wrap the column.

### 10.4 MySQL → Postgres comparison table

| Purpose | MySQL | Postgres |
|---|---|---|
| Day difference | `DATEDIFF(a, b)` | `a::date - b::date` |
| Date arithmetic | `DATE_ADD(d, INTERVAL 1 MONTH)` | `d + INTERVAL '1 month'` |
| Formatting | `DATE_FORMAT(d, '%Y-%m')` | `TO_CHAR(d, 'YYYY-MM')` |
| Month start | — | `DATE_TRUNC('month', d)` |
| Year extraction | `YEAR(d)` | `EXTRACT(YEAR FROM d)` |

One line: `DATEDIFF` counts boundaries; `DATE_ADD` clamps at month end; to aggregate by month, compress dates to `'%Y-%m'` first, then GROUP BY.

---

## 11. High-frequency patterns

### 11.1 Consecutive problems (180: numbers appearing ≥ 3 times consecutively)

Table Logs:

| id | num |
|----|-----|
| 1 | 1 |
| 2 | 1 |
| 3 | 1 |
| 4 | 2 |
| 5 | 1 |
| 6 | 2 |
| 7 | 2 |

Answer is **1** (ids 1, 2, 3 are three consecutive 1s); 2 doesn't count (only ids 6, 7).

```sql
SELECT DISTINCT l1.num AS ConsecutiveNums
FROM Logs l1
JOIN Logs l2 ON l2.id = l1.id + 1 AND l2.num = l1.num
JOIN Logs l3 ON l3.id = l2.id + 1 AND l3.num = l2.num;
```

Walk through (l1, l2, l3 are three "shadows" of the same table, pairing row by row):

- l1=id1 (num=1): l2 must be id=2 with num=1 → ✅; l3 must be id=3 with num=1 → ✅. **Passes** → 1 kept
- l1=id2 (num=1): l2=id3 ✅; l3=id4 but num=2 ≠ 1 ❌. Out
- l1=id4 (num=2): l2=id5, num=1 ≠ 2 ❌. Out
- l1=id6 (num=2): l2=id7 ✅; l3=id8 doesn't exist ❌. Out

Only l1.num=1 passes. `DISTINCT` dedups (if ids 1–5 were all 1, three groups would pass and the result would contain three 1s).

Key points:

- `l2.id = l1.id + 1` is the definition of "consecutive" — same idea as problem 197's `DATEDIFF=1` (197 is date-consecutive, this is id-consecutive)
- **Universal template**: N consecutive occurrences = N−1 self-joins
- **Analogy**: like a shift register doing pattern detection — `id+1` is clock alignment, matching `num` is data match, output fires only when all three stages align

**Consecutive variants**:

- **601 (stadium traffic)**: 180's variant — want **every row in each triple** (not just the first). s1 has three identities (start/middle/end), so OR:

```sql
SELECT DISTINCT s1.*
FROM Stadium s1, Stadium s2, Stadium s3
WHERE s1.people >= 100 AND s2.people >= 100 AND s3.people >= 100
  AND ((s1.id + 1 = s2.id AND s2.id + 1 = s3.id)   -- s1 is the 1st of the triple
    OR (s1.id - 1 = s2.id AND s1.id + 1 = s3.id)   -- s1 is the middle
    OR (s1.id - 2 = s2.id AND s1.id - 1 = s3.id)); -- s1 is the 3rd of the triple
```

- **603 (consecutive available seats)**: `ABS(c1.seat_id - c2.seat_id) = 1` for adjacency
- **550 (game play analysis IV)**: first find each player's **first** login day, then check the next day for the ratio — still `DATEDIFF=1` at the core, only the reference moves from "previous row" to "first login day"

### 11.2 Nth highest (176 second highest, 177 Nth highest)

Table Employee:

| id | salary |
|----|--------|
| 1 | 100 |
| 2 | 200 |
| 3 | 300 |
| 4 | 300 |

The second highest is **200** (the top 300 has two people).

**Approach 1: subquery + LIMIT (176 only)**

```sql
SELECT (SELECT DISTINCT salary FROM Employee
        ORDER BY salary DESC LIMIT 1 OFFSET 1) AS SecondHighestSalary;
```

Walk through: `DISTINCT salary` → 300, 200, 100; `ORDER BY DESC` → 300, 200, 100; `LIMIT 1 OFFSET 1` → skip row 1, take row 2 → **200**. The outer `SELECT (...)` is the shell: if there's only one distinct salary, the inner returns empty and the outer returns one **NULL** row — the problem requires "return NULL when there is no second highest"; without the shell you get an empty table and the verdict fails.

**Approach 2: DENSE_RANK (general; 177 just swaps 2 for N)**

```sql
SELECT salary FROM (
    SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM Employee
) t WHERE rnk = 2;
```

| salary | DENSE_RANK | RANK |
|--------|------------|------|
| 300 | 1 | 1 |
| 300 | 1 | 1 |
| 200 | **2** | **3** |
| 100 | 3 | 4 |

`DENSE_RANK` ranks 1,1,2,3 **without skipping**, so `WHERE rnk=2` gets 200 ✅; `RANK` goes 1,1,3,4 **skipping**, so `rnk=2` returns empty ❌. **Remember: Nth highest = DENSE_RANK() = N — never use RANK().**

### 11.3 TopN per group (184: highest salary per department, ties included)

Tables: Employee(id, name, salary, departmentId), Department(id, name).

| id | name | salary | departmentId | dept name |
|----|-------|--------|--------------|--------|
| 1 | Joe | 70000 | 1 | IT |
| 2 | Jim | 90000 | 1 | IT |
| 3 | Henry | 80000 | 2 | Sales |
| 4 | Sam | 60000 | 2 | Sales |
| 5 | Max | 90000 | 1 | IT |

Answer: IT's Jim and Max (both 90000 — **ties included**), Sales' Henry (80000).

```sql
WITH ranked AS (
    SELECT d.name AS Department, e.name AS Employee, e.salary,
           DENSE_RANK() OVER (PARTITION BY e.departmentId
                              ORDER BY e.salary DESC) AS rnk
    FROM Employee e
    JOIN Department d ON e.departmentId = d.id
)
SELECT Department, Employee, salary
FROM ranked
WHERE rnk = 1;
```

Walk through: JOIN attaches department names first; the window function ranks **independently within each department** (IT: Jim 1, Max 1, Joe 2; Sales: Henry 1, Sam 2); `WHERE rnk = 1` → Jim, Max, Henry.

Three details:

1. `DENSE_RANK`, not `ROW_NUMBER` — ROW_NUMBER would force Jim=1, Max=2 (breaking the tie arbitrarily), dropping Max and failing the verdict
2. `PARTITION BY e.departmentId` — without it, the whole company gets one ranking and Sales' Henry never surfaces
3. WITH splits "ranking" and "filtering" into two steps

**Difference from 176**: 176 is the Nth highest over the whole table (no PARTITION); 184 is the Nth highest **per group** (with PARTITION) — recognize TopN-per-group problems at a glance.

### 11.4 Conditional percentage (1211, 1633)

See 9.3. Universal formula: `AVG(CASE WHEN condition THEN 1 ELSE 0 END)` = the share satisfying the condition.

### 11.5 Group by month (1193)

Table Transactions:

| id | country | state | amount | trans_date |
|----|---------|----------|--------|------------|
| 1 | US | approved | 1000 | 2018-12-18 |
| 2 | US | declined | 2000 | 2018-12-19 |
| 3 | US | approved | 2000 | 2019-01-01 |

```sql
SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month,
       country,
       COUNT(*) AS trans_count,
       SUM(CASE WHEN state = 'approved' THEN 1 ELSE 0 END) AS approved_count,
       SUM(amount) AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY month, country;
```

| month | country | trans_count | approved_count | trans_total_amount | approved_total_amount |
|---------|---------|-------------|----------------|--------------------|-----------------------|
| 2018-12 | US | 2 | 1 | 3000 | 1000 |
| 2019-01 | US | 1 | 1 | 2000 | 2000 |

Three concepts in one shot:

1. `DATE_FORMAT(trans_date, '%Y-%m')` → `'2018-12'`: the group-by-month tool
2. `GROUP BY month, country`: multi-column grouping
3. `SUM(CASE WHEN state='approved' THEN amount ELSE 0 END)`: **conditional sum** — CASE WHEN's second use

**1174** adds one more layer: first find each user's first order date with a subquery/WITH, then CASE WHEN for immediacy, then compute the ratio.

### 11.6 Row-to-column pivot (1179)

Table Department:

| id | revenue | month |
|-----|---------|-------|
| 1 | 8000 | Jan |
| 1 | 7000 | Feb |
| 1 | 9000 | Mar |
| 2 | 6000 | Jan |
| 2 | 5000 | Feb |

Requirement: one row per id, one column per each of 12 months.

```sql
SELECT id,
       SUM(CASE WHEN month = 'Jan' THEN revenue END) AS Jan_Revenue,
       SUM(CASE WHEN month = 'Feb' THEN revenue END) AS Feb_Revenue,
       SUM(CASE WHEN month = 'Mar' THEN revenue END) AS Mar_Revenue
       -- ... Apr through Dec likewise
FROM Department
GROUP BY id;
```

Walk through (Jan_Revenue column for id=1): each of the 5 rows passes `CASE WHEN month='Jan'`: (1,8000,Jan)→8000; (1,7000,Feb)→NULL; (1,9000,Mar)→NULL; (2,6000,Jan)→6000; (2,5000,Feb)→NULL. After `GROUP BY id`, `SUM`: id=1 group 8000+NULL+NULL = **8000**; id=2 group 6000+NULL = **6000**.

| id | Jan_Revenue | Feb_Revenue | Mar_Revenue |
|-----|-------------|-------------|-------------|
| 1 | 8000 | 7000 | 9000 |
| 2 | 6000 | 5000 | NULL |

Key point: **no ELSE** in `SUM(CASE WHEN ...)` — non-matching is NULL, and SUM ignores NULLs. Fixed template: **CASE WHEN builds columns + aggregation squeezes rows + GROUP BY sets the grain**. 1795 and 1777 are the same mold.

### 11.7 Sliding window / running total (1321, 1204)

**1321: 7-day restaurant revenue (sliding window)**

Table Customer (pre-aggregated per day):

| visited_on | amount |
|------------|--------|
| 2019-01-01 | 100 |
| 2019-01-02 | 110 |
| 2019-01-03 | 120 |
| 2019-01-04 | 130 |
| 2019-01-05 | 140 |
| 2019-01-06 | 150 |
| 2019-01-07 | 160 |
| 2019-01-08 | 170 |

```sql
SELECT visited_on,
       SUM(amount) OVER (ORDER BY visited_on
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount,
       ROUND(AVG(amount) OVER (ORDER BY visited_on
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS average_amount
FROM (SELECT visited_on, SUM(amount) AS amount
      FROM Customer GROUP BY visited_on) t
ORDER BY visited_on
OFFSET 6;
```

- `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`: the window is "6 rows back plus current, 7 rows total" — a **sliding** 7-day frame
- Row 01-07: window 01-01~01-07, sum = 910, avg = 130.00
- Row 01-08: window slides to 01-02~01-08, sum = 980, avg = 140.00
- `OFFSET 6`: the first 6 days have incomplete windows — skip them; **the first valid output row is day 7**

Key point: first aggregate per day in a subquery (`GROUP BY`, since one day can have multiple records), then open the window.

**1204: the last person to board the bus (running total)**

Table Queue (turn = boarding order):

| person_id | person_name | weight | turn |
|-----------|-------------|--------|------|
| 5 | Alice | 250 | 1 |
| 4 | Bob | 175 | 2 |
| 3 | Alex | 350 | 3 |
| 6 | John | 400 | 4 |
| 1 | Winston | 500 | 5 |

Bus limit 1000.

```sql
SELECT person_name FROM (
    SELECT person_name,
           SUM(weight) OVER (ORDER BY turn) AS total
    FROM Queue
) t
WHERE total <= 1000
ORDER BY total DESC
LIMIT 1;
```

`SUM(...) OVER (ORDER BY turn)` defaults to the frame "row 1 through current row" — naturally a running total: Alice 250 → Bob 425 → Alex 775 → John 1175 (over). `WHERE total <= 1000` keeps the first three, `ORDER BY total DESC LIMIT 1` → **Alex** ✅.

Key point: a windowed aggregate without an explicit frame defaults to accumulation. 1204 vs 1321: one "accumulates from the start", the other "slides a fixed 7-row frame".

### 11.8 GROUP_CONCAT / string_agg (1484)

Table Activities:

| sell_date | product |
|------------|-----------|
| 2020-05-30 | Headphone |
| 2020-05-30 | Basketball|
| 2020-05-30 | T-Shirt |
| 2020-06-01 | Pencil |
| 2020-06-01 | Mask |
| 2020-06-01 | Bible |
| 2020-06-01 | Mask |

Requirement: per day, how many distinct products sold, and product names sorted alphabetically joined into a string.

```sql
-- MySQL
SELECT sell_date,
       COUNT(DISTINCT product) AS num_sold,
       GROUP_CONCAT(DISTINCT product ORDER BY product SEPARATOR ',') AS products
FROM Activities
GROUP BY sell_date;
-- PostgreSQL version: string_agg(DISTINCT product, ',' ORDER BY product)
```

| sell_date | num_sold | products |
|------------|----------|----------------------------|
| 2020-05-30 | 3 | Basketball,Headphone,T-Shirt |
| 2020-06-01 | 4 | Bible,Mask,Pencil |

Key point: `DISTINCT` goes **inside** the function, not outside — `GROUP_CONCAT(DISTINCT product ...)`.

### 11.9 High-frequency pattern one-liners

| Topic | One line | Gatekeeper problems |
|---|---|---|
| Consecutive | N−1 self-joins, or date minus ROW_NUMBER | 180, 601, 603, 550 |
| Nth highest | DENSE_RANK() = N (not RANK) | 176, 177 |
| TopN per group | WITH + DENSE_RANK, ties included | 184 |
| Conditional percentage | AVG(CASE WHEN condition THEN 1 ELSE 0 END) | 1211, 1633 |
| Group by month | DATE_FORMAT + multi-column GROUP BY + conditional sum | 1193, 1174 |
| HAVING | WHERE after grouping, aggregate conditions only | 596, 182, 1070 |
| Pivot | CASE WHEN builds columns + aggregation squeezes rows + GROUP BY sets grain | 1179, 1795, 1777 |
| Sliding window | ROWS BETWEEN n PRECEDING AND CURRENT ROW | 1321, 1204 |
| String functions | cut (SUBSTRING), change (UPPER/LOWER), join (CONCAT) | 1667 |
| Anti-join | NOT EXISTS or LEFT JOIN…IS NULL, never NOT IN | 183, 1581 |
| DELETE | self-join finds "rows to delete"; SELECT-verify first in production | 196 |
| UPDATE | one statement with CASE WHEN swaps — never two statements | 627 |

---

## 12. Performance: naked columns, slow queries, indexes, EXPLAIN

### 12.1 Keep the column "naked" (sargable)

"Naked" means: the column compared in WHERE wears no function, no arithmetic — it stays as it is.

```sql
-- ❌ clothed: the column is wrapped in a function
SELECT * FROM orders WHERE YEAR(created_at) = 2024;
SELECT * FROM orders WHERE DATE(created_at) = '2024-01-10';

-- ✅ naked: the column is clean, all computation on the constant side
SELECT * FROM orders
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
SELECT * FROM orders
WHERE created_at >= '2024-01-10' AND created_at < '2024-01-11';
```

**Why clothed columns can't use indexes**: a B-tree index stores the column's **raw values** sorted. `WHERE created_at >= '2024-01-01'` translates directly to "start scanning the index from this position" — one lookup. But `YEAR(created_at) = 2024` asks for "rows whose function result equals 2024" — the index doesn't store `YEAR()` results, the optimizer can't position, so it fetches all 1M rows and computes `YEAR()` on each — Seq Scan, the 28-second slow query came from exactly this.

Dictionary analogy: a dictionary is sorted by pinyin. Ask for "words whose 3rd letter is a" and you must flip through the whole book; ask for "words starting with zha" and you jump straight to the zha page. A function on the column = a different sort key, and the table of contents is void.

**Common "clothed" sites and fixes**:

| Clothed | Naked fix |
|---|---|
| `WHERE DATE(created_at) = '2024-01-10'` | `WHERE created_at >= '2024-01-10' AND created_at < '2024-01-11'` |
| `WHERE YEAR(x)=2024 AND MONTH(x)=1` | `WHERE x >= '2024-01-01' AND x < '2024-02-01'` |
| `WHERE amount + tax > 100` | `WHERE amount > 100 - tax` (move the arithmetic to the constant side) |
| `WHERE UPPER(name) = 'ZHANG'` | store uppercase at insert time, or build a function index |
| `WHERE name LIKE '%zhang'` | leading-wildcard LIKE can't use B-tree either — switch to full-text or an inverted approach |

**The term**: this is **sargable** (Search ARGument ABLE) — "the condition can be used for index seeks". In an interview, "how do you write a WHERE that uses the index?" is answered with exactly this.

**The one exception**: expression (function) indexes. Postgres allows `CREATE INDEX idx ON orders (DATE(created_at))` — the index stores the computed values directly, and then `WHERE DATE(created_at) = ...` uses it. But that's an explicit, unconventional weapon; by default it doesn't exist — so the iron rule stands: keep columns naked first, consider function indexes only when truly needed.

### 12.2 Slow query optimization: 28 seconds → 12 ms

Scenario: 1M rows in orders, query one customer's 2024 orders.

**Slow version (28 s) — three sins**:

```sql
SELECT * FROM orders
WHERE customer_id = 123 AND YEAR(created_at) = 2024;
```

1. `YEAR(created_at)` wraps the column in a function → **index dead** (compute per row, compare per row, full table scan)
2. `SELECT *` → drags every column back, doubling I/O
3. No index on `(customer_id, created_at)`

**Fast version (12 ms)**:

```sql
SELECT order_id, amount, created_at FROM orders
WHERE customer_id = 123
  AND created_at >= '2024-01-01' AND created_at < '2025-01-01';

CREATE INDEX idx_orders_cust_time ON orders (customer_id, created_at);
```

1. Function replaced by a **range condition** → index usable
2. Only the needed columns
3. Build a **composite index**: equality column `customer_id` first, range column `created_at` after (**leftmost-prefix principle**)

**The four optimization steps**: `EXPLAIN` the plan → rewrite (drop functions, drop SELECT *) → add index (equality first, range after) → `EXPLAIN` again to verify.

### 12.3 EXPLAIN ANALYZE full reading + pg_stat_statements

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT amount FROM orders
WHERE customer_id = 123 AND created_at >= '2024-01-01';
```

Sample output:

```
Index Scan using idx_orders_cust_time on orders
 (cost=0.42..8.44 rows=1 width=8)
 (actual time=0.031..0.033 rows=2 loops=1)
 Index Cond: ((customer_id = 123) AND (created_at >= '2024-01-01'))
 Buffers: shared hit=5
Planning Time: 0.123 ms
Execution Time: 0.045 ms
```

Read it line by line:

- `Index Scan using ...`: used the index ✅ (`Seq Scan` would be a full table scan — be alarmed)
- `cost=0.42..8.44`: the optimizer's **estimated** cost (startup..total); `actual time=0.031..0.033`: **real** time. Big gap between estimate and reality → stale statistics, run `ANALYZE orders;`
- `rows=1` vs actual `rows=2`: estimated row count — worry when off by an order of magnitude
- `Buffers: shared hit=5`: all 5 pages hit in memory, no disk reads
- `Execution Time: 0.045 ms`: real execution time — **ANALYZE actually runs the query**, never add it to write operations!

**Finding slow queries**:

```sql
CREATE EXTENSION pg_stat_statements;
SELECT query, calls, ROUND(mean_exec_time::numeric, 2) AS avg_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;
-- lists the 5 queries with the highest average time — start optimizing here
```

### 12.4 Index deep dive

| Type | Good at | Create |
|---|---|---|
| B-tree (default) | equality, range, sort | `CREATE INDEX idx ON t(col)` |
| Hash | equality `=` only | `CREATE INDEX idx ON t USING HASH (col)` |
| GIN | full-text, arrays, jsonb | `CREATE INDEX idx ON t USING GIN (to_tsvector('english', body))` |

**Partial index** — index only the "hot" data, small and fast:

```sql
CREATE INDEX idx_active_orders ON orders (customer_id)
WHERE state = 'active';
-- active-order queries use this small index; history queries unaffected
```

**Covering index** — stuff the queried columns into the index, no table lookup:

```sql
CREATE INDEX idx_cov ON orders (customer_id) INCLUDE (amount, created_at);
-- SELECT amount, created_at WHERE customer_id = 123 → Index Only Scan, never touches the table
```

Mnemonic: B-tree for equality + range; GIN for `@>` on arrays/jsonb; partial indexes for hot subsets; INCLUDE for covering when the SELECT list is fixed and small.

**Learning path**: W1D4 learn diagnosis (EXPLAIN) → D6 learn prescriptions (rewrite + indexes) → W2 learn emergency room (production incidents) → W3 learn explaining it to the interviewer.

---

## 13. DBA practice

DBAs also write queries, but with a different emphasis:

| | LeetCode | DBA ops |
|---|---|---|
| Goal | write complex queries | read + optimize other people's queries |
| Typical | TopN per group | `SELECT * FROM pg_stat_activity WHERE state='active'` |

The four queries a DBA writes daily: read a customer's slow query → rewrite and optimize → system-catalog queries (pg_stat_*) → SQL inside inspection scripts. The query fundamentals from D1–D2 are the foundation for W2 and for gigs: without them you can't even read EXPLAIN output.

### 13.1 Transactions: ACID, isolation levels, locks

**The transfer example** — all succeed or none execute:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT; -- commit only when both succeed
-- on error: ROLLBACK; undoes both together
```

**ACID in one line**: A atomicity (all or nothing), C consistency (money never vanishes), I isolation (concurrent transactions don't interfere), D durability (committed is never lost).

**Isolation levels** (four gears against concurrency problems, weakest to strongest):

| Level | Problem solved | Example |
|---|---|---|
| Read Uncommitted | defends nothing | reads someone else's uncommitted data (dirty read) |
| Read Committed (PG default) | prevents dirty reads | two reads of the same row in one transaction can differ (non-repeatable read) |
| Repeatable Read | prevents non-repeatable reads | two count queries differ (phantom read: someone inserted new rows) |
| Serializable | prevents everything | slowest, serial execution |

**Row-lock practice** — two sessions decrementing stock:

```sql
-- session A
BEGIN;
SELECT stock FROM products WHERE id = 1 FOR UPDATE; -- locks this row
UPDATE products SET stock = stock - 1 WHERE id = 1;
COMMIT; -- lock released on commit
```

Session B's `FOR UPDATE` on the same row **blocks** until A commits — that's how overselling is prevented. **Analogy**: like bus arbitration — `FOR UPDATE` requests an exclusive lock, and only the lock holder may modify.

### 13.2 Backup and recovery

```bash
# full logical backup (custom format, single-table restore possible)
pg_dump -U postgres -d shop -F c -f shop_backup.dump

# one table only
pg_dump -U postgres -d shop -t orders -F c -f orders.dump

# restore into a new database
pg_restore -U postgres -d shop_new -c shop_backup.dump
```

Two backup kinds:

- **Logical backup** (pg_dump): exports SQL/archive, cross-version compatible, single-table restore; downside is slow on huge databases
- **Physical backup** (pg_basebackup): whole disk-file copy, fast, good for disaster recovery of big databases; downside is the version must match exactly

**Iron rule**: a backup whose restore was never rehearsed is no backup — regularly restore into a test database.

### 13.3 Partitioned tables, materialized views

**Partitioned tables** — slice a huge table by time; querying one month scans one partition:

```sql
CREATE TABLE orders (
    order_id int, customer_id int, amount numeric, created_at date
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE orders_2024q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
```

`INSERT` routes automatically to the right partition by date; `WHERE created_at >= '2024-02-01'` scans only the q1 partition (**partition pruning**). **Analogy**: like memory banks sliced by address — only the selected bank is accessed.

**Materialized views** — "freeze" a slow query's result:

```sql
CREATE MATERIALIZED VIEW monthly_sales AS
SELECT DATE_TRUNC('month', created_at) AS m, SUM(amount) AS total
FROM orders GROUP BY 1;

REFRESH MATERIALIZED VIEW monthly_sales; -- refresh manually when data changes
```

| | Regular VIEW | Materialized view |
|---|---|---|
| Stores data? | no, queries live every time | stores the result set |
| Speed | slow (recomputed every time) | fast (read directly) |
| Freshness | real-time | manual REFRESH |

Fits "slow to compute, read often, low real-time requirement" reports.

### 13.4 Five Postgres-only goodies

```sql
-- 1. generate_series: the data generator
SELECT generate_series(1, 5); -- 1,2,3,4,5
SELECT generate_series('2024-01-01'::date, '2024-01-07'::date, '1 day'::interval);
-- 7 consecutive dates; pair with LEFT JOIN to find "which days have no data"

-- 2. FILTER: conditional aggregation, cleaner than CASE WHEN
SELECT COUNT(*) FILTER (WHERE state = 'approved') AS approved_count,
       COUNT(*) AS total
FROM orders;

-- 3. DISTINCT ON: first row per group (MySQL doesn't have it!)
SELECT DISTINCT ON (dept) name, dept, salary
FROM emp ORDER BY dept, salary DESC;
-- keep only the top earner per department: Zhang San(IT), Wang Wu(Sales), Qian Qi(HR)

-- 4. RETURNING: get it back right after writing (no second SELECT needed)
INSERT INTO users(name) VALUES ('Tom') RETURNING id;
UPDATE emp SET salary = salary * 1.1 WHERE dept = 'IT' RETURNING name, salary;
DELETE FROM orders WHERE created_at < '2020-01-01' RETURNING order_id;

-- 5. array_agg: aggregate a column into an array
SELECT dept, array_agg(name ORDER BY salary DESC) AS members
FROM emp GROUP BY dept;
-- IT: {Zhang San,Li Si} Sales: {Wang Wu,Zhao Liu} HR: {Qian Qi}
```

Key points: `DISTINCT ON` requires the `ORDER BY`'s first column to be the `DISTINCT ON` column — a hard syntax rule; `FILTER` is equivalent to `CASE WHEN`, pick whichever reads better.

---

## 14. Strings / regex / UPDATE / DELETE

### 14.1 String functions (1667: fix the names)

Table Users:

| user_id | name |
|---------|-------|
| 1 | aLice |
| 2 | bOB |

Requirement: capitalize the first letter, lowercase the rest → Alice, Bob.

```sql
SELECT user_id,
       CONCAT(UPPER(SUBSTRING(name, 1, 1)),
              LOWER(SUBSTRING(name, 2))) AS name
FROM Users
ORDER BY user_id;
```

Walk through with `'aLice'`:

1. `SUBSTRING('aLice', 1, 1)` → `'a'` (take 1 char starting at position 1 — **SQL indexes start at 1, not 0!**)
2. `UPPER('a')` → `'A'`
3. `SUBSTRING('aLice', 2)` → `'Lice'` (from position 2 to the end; omit the length to go to the end)
4. `LOWER('Lice')` → `'lice'`
5. `CONCAT('A', 'lice')` → `'Alice'` ✅

**Memory aid**: string functions are just three moves — **cut** (SUBSTRING), **change** (UPPER/LOWER), **join** (CONCAT). `LENGTH` counts length (problem 1683 uses `LENGTH(content) > 15`), `REPLACE(phone, '-', '')` strips dashes.

### 14.2 Regex (1517: find users with valid emails)

Valid rules: prefix starts with a letter, contains only letters/digits `_` `.` `-`, domain must be `@leetcode.com`.

```sql
SELECT * FROM Users
WHERE mail REGEXP '^[a-zA-Z][a-zA-Z0-9_.-]*@leetcode\\.com$';
```

Regex broken down:

| Fragment | Meaning |
|---|---|
| `^` | start of string (without it, `winston@...` inside `1winston@...` could match) |
| `[a-zA-Z]` | first character must be a letter |
| `[a-zA-Z0-9_.-]*` | followed by zero or more legal characters |
| `@leetcode` | literal |
| `\\.` | escaped dot (unescaped `.` means "any character", letting `@leetcodeXcom` slip through) |
| `com$` | must end with com |

Test cases: `winston@leetcode.com` ✅; `1winston@leetcode.com` ❌ (first char is a digit); `winston#1@leetcode.com` ❌ (`#` illegal); `winston@leet.code.com` ❌ (`$` can't anchor).

Key point: `^` and `$` are **anchors** — missing either can let invalid input through; the most common point loss in regex problems.

### 14.3 UPDATE (627: swap genders)

Table Salary:

| id | name | sex | salary |
|-----|------|-----|--------|
| 1 | A | m | 2500 |
| 2 | B | f | 1500 |
| 3 | C | m | 5500 |
| 4 | D | f | 500 |

Requirement: swap m↔f.

```sql
UPDATE Salary
SET sex = CASE WHEN sex = 'm' THEN 'f' ELSE 'm' END;
```

One statement executes **atomically**, each row judged independently: A m→f, B f→m, C m→f, D f→m — all swapped at once.

**Pitfall**: never write it as two statements:

```sql
UPDATE Salary SET sex = 'f' WHERE sex = 'm'; -- everything becomes f
UPDATE Salary SET sex = 'm' WHERE sex = 'f'; -- everything becomes m, all wrong!
```

After statement 1 there are no m's left; statement 2 flips all f's (including the just-swapped ones) to m. Like 196's DELETE, **SELECT to check the affected rows first in production**.

### 14.4 DELETE (196: delete duplicate emails, keep the smallest id)

Table Person:

| id | email |
|----|------------------|
| 1 | john@example.com |
| 2 | bob@example.com |
| 3 | john@example.com |

john is duplicated; keep id=1, delete id=3.

```sql
DELETE p1
FROM Person p1
JOIN Person p2 ON p1.email = p2.email AND p1.id > p2.id;
```

Walk through — the self-join finds "rows that have a smaller id with the same email" (those are the ones to delete):

- p1=id1 (john): p2=id1 (id not greater than itself) ❌; p2=id3 (same email but 1>3 false) ❌. **No smaller same-email row — keep** ✅
- p1=id2 (bob): no same-email row ❌. Keep ✅
- p1=id3 (john): p2=id1, same email ✅ and 3>1 ✅. **Delete** ❌
- `DELETE p1`: only deletes rows p1 points at (id=3); p2 is only the "identifier", not deleted

**Production iron rule**: first replace `DELETE p1` with `SELECT p1.*` and run it, confirm the target is exactly id=3, then switch back to DELETE. LeetCode lets you roll back; production deletions are gone for good.

---

## 15. LeetCode 10-problem walkthrough

(2026-10-18's 10 problems, each explained. 197 and 584 are also covered in Sections 6 and 11 — the most complete version is kept here.)

### 15.1 1661 Average Time of Process per Machine

See 2.4. Self-join pairing; all four ON conditions required; `ROUND(..., 3)` keeps 3 decimals.

### 15.2 197 Rising Temperature

Table Weather(id, recordDate, temperature). Find ids of days hotter than the previous day.

```sql
SELECT w1.id
FROM Weather w1
JOIN Weather w2 ON DATEDIFF(w1.recordDate, w2.recordDate) = 1
WHERE w1.temperature > w2.temperature;
```

- DATEDIFF(later, earlier): MySQL's argument order is (bigger date, smaller date)
- `= 1` is the soul: the two days must be adjacent

Pitfall: using LAG(temperature) to take the "previous row" — when a day is missing, the previous row could be 3 days ago. "Previous row" is not "previous day"; you must explicitly check the date difference. Whenever a problem says "previous day / consecutive", think of missing dates first.

### 15.3 1581 Customers Who Never Transact

See 7.3. "Has A, lacks B" = LEFT JOIN + IS NULL.

### 15.4 1068 Product Sales Analysis I

```sql
SELECT p.product_name, s.year, s.price
FROM Sales s
JOIN Product p ON s.product_id = p.product_id;
```

A pure JOIN primer — no pitfalls.

### 15.5 1378 Replace Employee ID

```sql
SELECT u.unique_id, e.name
FROM Employees e
LEFT JOIN EmployeeUNI u ON e.id = u.id;
```

Pitfall: INNER JOIN would drop employees with no unique_id. Remember: "show even when missing" means LEFT JOIN.

### 15.6 1683 Invalid Tweets

```sql
SELECT tweet_id FROM Tweets WHERE LENGTH(content) > 15;
```

Pitfall: it's `>`, not `>=`. In MySQL, LENGTH counts bytes, CHAR_LENGTH counts characters — same for English, use CHAR_LENGTH for Chinese text.

### 15.7 1148 Article Views I

```sql
SELECT DISTINCT author_id AS id
FROM Views
WHERE author_id = viewer_id
ORDER BY id;
```

Three test points: self-view (author=viewer), dedup (same person views multiple times), column name + ordering. Missing any one fails the verdict.

### 15.8 595 Big Countries

```sql
SELECT name, population, area FROM World
WHERE area >= 3000000 OR population >= 25000000;
```

Pitfall: it's OR not AND, `>=` not `>`. In Easy problems all pitfalls are in reading — circle the condition words before writing.

### 15.9 584 Find Customer Referee

```sql
SELECT name FROM Customer
WHERE referee_id != 2 OR referee_id IS NULL;
```

Pitfall (LeetCode's favorite NULL trap): `referee_id != 2` returns NULL for NULL rows, and WHERE drops them — you must add `OR referee_id IS NULL` to pick them back up.

Memorize the pattern: `col != value OR col IS NULL` — the standard form for "not equal to a value (including empty)".

### 15.10 1757 Recyclable and Low Fat Products

```sql
SELECT product_id FROM Products
WHERE low_fats = 'Y' AND recyclable = 'Y';
```

Just Enum comparison — compare directly as strings. Note this is AND (both required), contrast with 595's OR.

### 15.11 Pattern summary table

| # | Pattern | Pitfall |
|---|---|---|
| 1661 | self-join pairing | missing the activity_type condition |
| 197 | date continuity | previous row ≠ previous day, DATEDIFF=1 |
| 1581 | LEFT JOIN + IS NULL (has A, lacks B) | — |
| 1068 | basic JOIN | — |
| 1378 | LEFT JOIN ("show even when missing") | don't use INNER |
| 1683 | LENGTH | `>` not `>=` |
| 1148 | self-reference + DISTINCT + renamed sort | all three test points required |
| 595 | OR + `>=` | read carefully |
| 584 | NULL trap | `!= value OR IS NULL` |
| 1757 | Enum comparison | AND not OR |

197 and 584 deserve the most rework: one tests date thinking, the other NULL thinking — both recur in Medium problems.

---

## 16. Appendix

### 16.1 The 28 SQL iron rules

**NULL (first rule of data work: always assume columns contain NULL)**

1. WHERE only accepts TRUE — `TRUE AND NULL` gives NULL and the row is filtered; `FALSE AND NULL` gives FALSE; `TRUE OR NULL` gives TRUE; `FALSE OR NULL` gives NULL
2. See NULL with NOT IN, switch to NOT EXISTS — IN is an OR chain where TRUE short-circuits past NULL; NOT IN is an AND chain where NULL poisons TRUE; the asymmetry is the root cause
3. "Has A, lacks B" queries always use NOT EXISTS or LEFT JOIN…IS NULL, never NOT IN
4. `COUNT(*)` counts rows; `COUNT(col)` skips NULLs; `COUNT(DISTINCT col)` counts distinct non-NULLs; all NULLs huddle into one group in GROUP BY

**Query writing**

5. IN goes with small lists; EXISTS only asks "is there any"
6. Execution order: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT — so WHERE can't use SELECT aliases
7. HAVING = WHERE after grouping; aggregate conditions only
8. In JOINs, ON controls matching eligibility, WHERE filters the result
9. WITH = name + stepwise, the cure for nested-subquery hell; only later CTEs can reference earlier ones

**Performance**

10. Keep the column naked (sargable) — functions/arithmetic on a column kill the index; move computation to the constant side
11. The four slow-query steps: EXPLAIN → rewrite → add index → EXPLAIN again to verify
12. Composite indexes: equality columns first, range columns after (leftmost-prefix principle)
13. SELECT * is technical debt — take only the columns you need
14. UNION dedups slowly; default to UNION ALL

**High-frequency patterns**

15. LAG's previous row ≠ previous day (197)
16. Nth highest uses DENSE_RANK, not RANK; when 176 has no result it must return NULL — wrap it in another SELECT
17. TopN per group: WITH + DENSE_RANK + PARTITION BY; ties must be included, so no ROW_NUMBER (184)
18. N consecutive occurrences: N−1 self-joins (180)
19. Conditional percentage: AVG(CASE WHEN condition THEN 1 ELSE 0 END) (1211)
20. Pivot: CASE WHEN builds columns + aggregation squeezes rows + GROUP BY sets the grain (1179)
21. "How many distinct b per a": COUNT(DISTINCT b) (1693)

**Writing data**

22. An UPDATE swap is one statement — never two (627)
23. In production, SELECT-verify first, then UPDATE/DELETE (196)
24. A backup whose restore was never rehearsed is no backup

**Thinking and dates**

25. Python is imperative (sequential logic), SQL is declarative (combinational logic), AI is probabilistic (Monte Carlo); NULL ≈ the X state in Verilog
26. AI apps = Python builds the pipeline (hands) + SQL manages the data (eyes) + probabilistic thinking does the evaluation (brain)
27. DATEDIFF counts crossed date boundaries; DATE_ADD clamps at month end; '%Y-%m' is the group-by-month tool
28. Last-N-days filtering: NOW() for exact lookback, CURDATE() for calendar days, never wrap the column

### 16.2 Mastery matrix (assessed 2026-10-19)

- ✅ Mastered: basic SELECT / WHERE / ORDER BY / LIMIT; simple JOINs, LEFT JOIN; INSERT; simple aggregation
- 🟡 Half-mastered: the three ranking window functions (gatekeepers 178, 184); LEFT JOIN + IS NULL; subqueries (176); CASE WHEN conditional stats (1211); date functions (1193); WITH/CTE (184); self-joins (197 rework)
- 🔴 Not yet mastered at the time (all covered in this compendium): HAVING in combined use (1070); consecutive problems (180); Nth highest (176, 177); string functions (1667, 1527); DELETE (196); conditional percentage (1211, 1633); group by month (1193, 1174)

### 16.3 Three kinds of thinking

- Imperative (Python) = sequential logic / state machines: step by step, deterministic
- Declarative / set-based (SQL) = combinational logic / dataflow: describe what you want, transform whole tables
- Probabilistic (AI apps) = Monte Carlo / mismatch analysis: outputs uncertain, the distribution is what's optimized

SQL's NULL = Verilog's X state: `NULL = 1` → NULL, just as `X == 1` → X; COALESCE is "assign a default to X".

### 16.4 Suggested practice / hands-on order

1. Rework **197, 584** first (date thinking + NULL thinking — best ROI)
2. Gatekeepers: **180 → 176 → 184 → 1211 → 1193** (write each from memory with notes closed; come back when stuck)
3. New-pattern warm-ups: **596 → 182 → 181 → 601** (one per half hour) → **1321 → 1204** (window frames) → recursive CTE (hardest, reserve a dedicated block)
4. The 6 DBA points (transactions / advanced indexes / EXPLAIN / backup / partitioning / PG-only features): verify hands-on after the D3 Docker Postgres environment is up
5. Sort mistakes into "window functions / aggregation / JOIN / subqueries" and revisit the matching section here

### 16.5 Learning sites

| Site | Use |
|---|---|
| SQLBolt (sqlbolt.com) | Lessons 5–8 aggregation primer |
| LeetCode Top SQL 50 | main battleground |
| Mode SQL Tutorial | window-function concepts, free interactive exercises |
| PostgreSQLTutorial | PG window functions, verifiable in psql |

---

*Source: 10 SQL study emails (#21 – #30), Oct 17 – Oct 19, 2026, deduplicated and merged. The D1 SQL guide is outside this compendium's scope.*
