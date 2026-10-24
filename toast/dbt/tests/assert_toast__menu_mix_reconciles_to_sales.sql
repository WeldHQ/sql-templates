-- Net sales summed over menu items equals net sales in the sales summary, per
-- business day and restaurant. Both apply the same void, delete and deferred
-- rules, so a gap means one of them fanned out or dropped selections.
-- Returns zero rows when they agree within a cent per row.

WITH items AS (
    SELECT business_date, restaurant_id, SUM(net_sales) AS net_sales, COUNT(*) AS n
    FROM {{ ref('core_toast__menu_item_sales') }}
    GROUP BY 1, 2
),
summary AS (
    SELECT business_date, restaurant_id, SUM(net_sales) AS net_sales, COUNT(*) AS n
    FROM {{ ref('core_toast__sales_summary') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(i.business_date, s.business_date) AS business_date,
    COALESCE(i.restaurant_id, s.restaurant_id) AS restaurant_id,
    i.net_sales                                AS item_net_sales,
    s.net_sales                                AS summary_net_sales
FROM items i
FULL OUTER JOIN summary s USING (business_date, restaurant_id)
WHERE ABS(COALESCE(i.net_sales, 0) - COALESCE(s.net_sales, 0))
      > 0.01 * (COALESCE(i.n, 0) + COALESCE(s.n, 0))
