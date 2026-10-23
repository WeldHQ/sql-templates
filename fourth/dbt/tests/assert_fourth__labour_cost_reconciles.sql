-- Labour cost per day is the same in labour_cost_daily and labour_vs_sales.
-- Both read staging payroll; a difference means the department-location map
-- fanned rows out. Returns zero rows when they agree (to the cent).

WITH detail AS (
    SELECT date, SUM(labour_cost) AS labour_cost
    FROM {{ ref('core_fourth__labour_cost_daily') }}
    GROUP BY 1
),
summary AS (
    SELECT date, SUM(labour_cost) AS labour_cost
    FROM {{ ref('core_fourth__labour_vs_sales') }}
    GROUP BY 1
)

SELECT
    COALESCE(d.date, s.date) AS date,
    d.labour_cost            AS detail_labour_cost,
    s.labour_cost            AS summary_labour_cost
FROM detail d
FULL OUTER JOIN summary s USING (date)
WHERE ABS(COALESCE(d.labour_cost, 0) - COALESCE(s.labour_cost, 0)) > 0.05
