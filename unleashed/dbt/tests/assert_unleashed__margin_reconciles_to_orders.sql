-- Revenue in sales_margin equals the sum of bc_sub_total on completed orders, per
-- completed date. bc_sub_total is the order's lines after discount and before
-- tax, so a gap means order lines are missing or duplicated. Returns zero rows
-- when they agree within a unit of currency per day.

WITH margin AS (
    SELECT completed_date, SUM(revenue) AS revenue
    FROM {{ ref('core_unleashed__sales_margin') }}
    GROUP BY 1
),
orders AS (
    SELECT completed_date, SUM(bc_sub_total) AS revenue
    FROM {{ ref('stg_unleashed__sales_order') }}
    WHERE order_status = 'Completed'
    GROUP BY 1
)

SELECT
    COALESCE(m.completed_date, o.completed_date) AS completed_date,
    m.revenue                                    AS line_revenue,
    o.revenue                                    AS order_revenue
FROM margin m
FULL OUTER JOIN orders o USING (completed_date)
WHERE ABS(COALESCE(m.revenue, 0) - COALESCE(o.revenue, 0)) > 1
