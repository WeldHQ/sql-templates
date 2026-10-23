-- Total rounded hours in time_report equal total tracked hours in
-- weekly_utilization, per user. Both read the same time entries, so a difference
-- means one of them dropped or duplicated rows. Returns zero rows when they agree.

WITH tr AS (
    SELECT user_id, SUM(rounded_hours) AS hours
    FROM {{ ref('core_harvest__time_report') }}
    GROUP BY 1
),
wu AS (
    SELECT user_id, SUM(tracked_hours) AS hours
    FROM {{ ref('core_harvest__weekly_utilization') }}
    GROUP BY 1
)

SELECT
    COALESCE(tr.user_id, wu.user_id) AS user_id,
    tr.hours                         AS time_report_hours,
    wu.hours                         AS utilization_hours
FROM tr
FULL OUTER JOIN wu USING (user_id)
WHERE ABS(COALESCE(tr.hours, 0) - COALESCE(wu.hours, 0)) > 0.05
