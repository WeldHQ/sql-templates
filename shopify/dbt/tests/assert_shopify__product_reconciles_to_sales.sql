-- The product-level model must sum to the order-level model, day by day.
--
-- This is the test that catches the most real bugs. If it fails, the usual cause
-- is missing NULL-sku rows: drop the shipping, fee or gift-card rows and the
-- product model sits below the sales report by exactly their value. The second
-- most common cause is double-counted returns, where both the agreement RETURN
-- events and the per-line refund rows were summed instead of de-duplicated.
--
-- Returns zero rows when they agree. A cent of tolerance absorbs the rounding
-- introduced by distributing order-level money across lines by weight.

WITH order_level AS (
    SELECT
        date,
        shopify_store,
        SUM(net_sales)   AS net_sales,
        SUM(total_sales) AS total_sales
    FROM {{ ref('core_shopify__sales_over_time') }}
    GROUP BY 1, 2
),

product_level AS (
    SELECT
        date,
        shopify_store,
        SUM(net_sales)   AS net_sales,
        SUM(total_sales) AS total_sales
    FROM {{ ref('core_shopify__product_sales_over_time') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(o.date, p.date)                   AS date,
    COALESCE(o.shopify_store, p.shopify_store) AS shopify_store,
    o.net_sales                                AS order_level_net_sales,
    p.net_sales                                AS product_level_net_sales,
    ROUND(COALESCE(o.net_sales, 0) - COALESCE(p.net_sales, 0), 2)     AS net_sales_diff,
    ROUND(COALESCE(o.total_sales, 0) - COALESCE(p.total_sales, 0), 2) AS total_sales_diff
FROM order_level o
FULL OUTER JOIN product_level p USING (date, shopify_store)
WHERE ABS(COALESCE(o.net_sales, 0)   - COALESCE(p.net_sales, 0))   > 0.01
   OR ABS(COALESCE(o.total_sales, 0) - COALESCE(p.total_sales, 0)) > 0.01
