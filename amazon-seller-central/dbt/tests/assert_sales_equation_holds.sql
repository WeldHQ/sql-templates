-- The sales equation must hold on every day, for every seller and marketplace:
--   net_sales = gross_sales + discounts + returns
-- (discounts and returns are stored negative, so this is plain addition.)
--
-- Returns rows only when it does not. A cent of tolerance absorbs NUMERIC rounding;
-- anything larger is a real bug in the component definitions - almost always a sign
-- flip introduced in staging when a source column changed.

SELECT
    date,
    amazon_seller,
    marketplace,
    SUM(net_sales)                                          AS net_sales,
    SUM(gross_sales + discounts + returns)                  AS recomputed,
    SUM(net_sales) - SUM(gross_sales + discounts + returns)  AS diff
FROM {{ ref('core_amazon_seller__product_sales_over_time') }}
GROUP BY 1, 2, 3
HAVING ABS(SUM(net_sales) - SUM(gross_sales + discounts + returns)) > 0.01
