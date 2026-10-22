-- The sales equation must hold on every day, for every store:
--   net_sales = gross_sales + discounts + returns
-- (discounts and returns are stored negative, so this is plain addition.)
--
-- Returns rows only when it does not. Each column is rounded on its own, so up to
-- two cents per order of rounding is tolerated.

SELECT
    date,
    adobe_commerce_store,
    SUM(net_sales)                         AS net_sales,
    SUM(gross_sales + discounts + returns) AS recomputed
FROM {{ ref('core_adobe_commerce__sales_over_time') }}
GROUP BY 1, 2
HAVING ABS(SUM(net_sales) - SUM(gross_sales + discounts + returns)) > 0.02 * COUNT(*)
