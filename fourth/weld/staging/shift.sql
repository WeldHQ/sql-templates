-- staging.fourth.shift
-- Thin wrapper over raw `shift`: rota shifts per employee, with location and
-- department. One row per shift in its latest state.
--
-- Same de-duplication as staging.fourth.payroll: the raw key includes the shift's
-- start and end time, so a moved shift lands as a new row. Only rows from the most
-- recent read of each location-department-day are kept.

WITH latest_read AS (
    SELECT
        *,
        MAX(_weld_synced) OVER (PARTITION BY location_id, department_id, DATE(shift_date)) AS latest_synced
    FROM {{raw.fourth.shift}}
)

SELECT
    CAST(location_id AS STRING)         AS location_id,
    CAST(location_name AS STRING)       AS location_name,
    CAST(department_id AS STRING)       AS department_id,
    CAST(department_name AS STRING)     AS department_name,
    CAST(employee_id AS STRING)         AS employee_id,
    DATE(shift_date)                    AS shift_date,
    CAST(shift_start_time AS TIMESTAMP) AS shift_start_time,
    CAST(shift_end_time AS TIMESTAMP)   AS shift_end_time,
    CAST(shift_length AS FLOAT64)       AS shift_length,
    CAST(break_total AS FLOAT64)        AS break_total,
    CAST(shift_role AS STRING)          AS shift_role,
    COALESCE(is_passive_shift, FALSE)   AS is_passive_shift
FROM latest_read
WHERE _weld_synced = latest_synced
