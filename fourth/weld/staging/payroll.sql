-- staging.fourth.payroll
-- Thin wrapper over raw `payroll`: Fourth Team Hours labour cost per employee,
-- department, day and pay part. One row per payroll line in its latest state.
--
-- Why the de-duplication: the raw table is keyed on department, employee, date,
-- type, pay part, status AND hours. When a line's hours or status change in
-- Fourth, the new version lands as a new row and the old one stays. Each sync
-- re-reads whole days, so the rows from the most recent read of a department-day
-- are its current state; older rows for that department-day are dropped here.

WITH latest_read AS (
    SELECT
        *,
        MAX(_weld_synced) OVER (PARTITION BY department_id, DATE(date)) AS latest_synced
    FROM {{raw.fourth.payroll}}
)

SELECT
    CAST(department_id AS STRING)           AS department_id,
    CAST(department_name AS STRING)         AS department_name,
    CAST(department_code AS STRING)         AS department_code,
    CAST(employee_id AS STRING)             AS employee_id,
    CAST(employee_personnel_number AS STRING) AS employee_personnel_number,
    TRIM(CONCAT(COALESCE(employee_forename, ''), ' ', COALESCE(employee_surname, ''))) AS employee_name,
    DATE(date)                              AS date,
    CAST(type AS STRING)                    AS payroll_type,
    CAST(pay_part AS STRING)                AS pay_part,
    CAST(status AS STRING)                  AS status,
    CAST(role_name AS STRING)               AS role_name,
    CAST(role_area AS STRING)               AS role_area,
    CAST(hours AS FLOAT64)                  AS hours,
    CAST(rate AS FLOAT64)                   AS rate,
    CAST(pay_value AS FLOAT64)              AS pay_value,
    CAST(shift_pay_factor AS FLOAT64)       AS shift_pay_factor
FROM latest_read
WHERE _weld_synced = latest_synced
