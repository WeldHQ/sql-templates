-- The sales equation must hold on every day, for every store:
--   net_sales = gross_sales + discounts + returns
-- (discounts and returns are stored negative, so this is plain addition.)
--
-- Returns rows only when it does not. A cent of tolerance absorbs NUMERIC
-- rounding; anything larger is a real bug in the component definitions.

SELECT
    date,
    shopify_store,
    SUM(net_sales)                         AS net_sales,
    SUM(gross_sales + discounts + returns) AS recomputed,
    SUM(net_sales) - SUM(gross_sales + discounts + returns) AS diff
FROM {{ ref('core_shopify__sales_over_time') }}
GROUP BY 1, 2
HAVING ABS(SUM(net_sales) - SUM(gross_sales + discounts + returns)) > 0.01
