-- 01-basics.sql — SQL basics practice
-- Run with: psql -d labdb -f sql/01-basics.sql

-- Top 10 highest paid employees in 'analog' dept
SELECT name, salary
FROM employees
WHERE dept = 'analog'
ORDER BY salary DESC
LIMIT 10;

-- Average salary per department
SELECT dept, AVG(salary) AS avg_salary, COUNT(*) AS headcount
FROM employees
GROUP BY dept
ORDER BY avg_salary DESC;

-- Employees earning more than their department average (subquery)
SELECT name, dept, salary
FROM employees e
WHERE salary > (SELECT AVG(salary) FROM employees WHERE dept = e.dept);
