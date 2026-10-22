-- core.toast.labor_vs_sales
-- Labor cost as a share of net sales, and sales per labor hour, per restaurant
-- and business day.
-- Grain: business date x restaurant.
--
-- Net sales from core.toast.sales_summary, labor from core.toast.labor_by_job
-- (excluding jobs flagged "exclude from reporting"). To roll up, sum labor_cost,
-- labor_hours and net_sales first and divide; never average the ratios.

WITH sales AS (
    SELECT business_date, restaurant_id, ANY_VALUE(restaurant_name) AS restaurant_name,
           SUM(net_sales) AS net_sales, SUM(orders) AS orders, SUM(guests) AS guests
    FROM {{core.toast.sales_summary}}
    GROUP BY 1, 2
),

labor AS (
    SELECT business_date, restaurant_id,
           SUM(total_hours) AS labor_hours, SUM(labor_cost) AS labor_cost
    FROM {{core.toast.labor_by_job}}
    WHERE NOT COALESCE(exclude_from_reporting, FALSE)
    GROUP BY 1, 2
)

SELECT
    COALESCE(s.business_date, l.business_date)        AS business_date,
    COALESCE(s.restaurant_id, l.restaurant_id)        AS restaurant_id,
    s.restaurant_name,
    COALESCE(s.orders, 0)                             AS orders,
    COALESCE(s.guests, 0)                             AS guests,
    COALESCE(s.net_sales, 0)                          AS net_sales,
    COALESCE(l.labor_hours, 0)                        AS labor_hours,
    COALESCE(l.labor_cost, 0)                         AS labor_cost,
    SAFE_DIVIDE(l.labor_cost, s.net_sales)            AS labor_pct_of_net_sales,
    SAFE_DIVIDE(s.net_sales, l.labor_hours)           AS net_sales_per_labor_hour
FROM sales s
FULL OUTER JOIN labor l USING (business_date, restaurant_id)
