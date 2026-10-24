-- Company-wide, each month's starting headcount equals the previous month's
-- ending headcount. Returns zero rows when it holds.

WITH company AS (
    SELECT month_start, SUM(headcount_start) AS headcount_start, SUM(headcount_end) AS headcount_end
    FROM {{ ref('core_hibob__headcount_monthly') }}
    GROUP BY 1
),
paired AS (
    SELECT
        month_start,
        headcount_start,
        LAG(headcount_end) OVER (ORDER BY month_start) AS previous_headcount_end
    FROM company
)

SELECT *
FROM paired
WHERE previous_headcount_end IS NOT NULL
  AND headcount_start != previous_headcount_end
