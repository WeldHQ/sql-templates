-- The product model must sum to the sales model, day by day, on net sales and
-- units. Both are built from the same events with the same filters; if they
-- drift apart, one of them was changed without the other.
--
-- Returns zero rows when they agree. A cent of tolerance absorbs rounding.

WITH sales AS (
    SELECT date, tiktok_account, shop_id, currency,
           SUM(net_sales) AS net_sales, SUM(units) AS units
    FROM {{ ref('core_tiktok_shop__sales_over_time') }}
    GROUP BY 1, 2, 3, 4
),

product AS (
    SELECT date, tiktok_account, shop_id, currency,
           SUM(net_sales) AS net_sales, SUM(units) AS units
    FROM {{ ref('core_tiktok_shop__product_sales_over_time') }}
    GROUP BY 1, 2, 3, 4
)

SELECT
    COALESCE(s.date, p.date)                     AS date,
    COALESCE(s.tiktok_account, p.tiktok_account) AS tiktok_account,
    COALESCE(s.shop_id, p.shop_id)               AS shop_id,
    COALESCE(s.currency, p.currency)             AS currency,
    s.net_sales AS sales_net_sales,
    p.net_sales AS product_net_sales,
    s.units     AS sales_units,
    p.units     AS product_units
FROM sales s
FULL OUTER JOIN product p USING (date, tiktok_account, shop_id, currency)
WHERE ABS(COALESCE(s.net_sales, 0) - COALESCE(p.net_sales, 0)) > 0.01
   OR COALESCE(s.units, 0) != COALESCE(p.units, 0)
