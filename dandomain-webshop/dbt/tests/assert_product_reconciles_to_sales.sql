-- The product model must sum to the order model, order by order, on net_sales.
-- Discount codes are allocated to lines in core, so the two should tie to the cent.
-- An order present on one side only usually has no synced lines.

WITH order_level AS (
    SELECT dandomain_shop, order_id, SUM(net_sales) AS net_sales
    FROM {{ ref('core_dandomain_webshop__sales_over_time') }}
    GROUP BY 1, 2
),

product_level AS (
    SELECT dandomain_shop, order_id, SUM(net_sales) AS net_sales
    FROM {{ ref('core_dandomain_webshop__product_sales_over_time') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(o.dandomain_shop, p.dandomain_shop) AS dandomain_shop,
    COALESCE(o.order_id, p.order_id)             AS order_id,
    o.net_sales AS order_level_net_sales,
    p.net_sales AS product_level_net_sales
FROM order_level o
FULL OUTER JOIN product_level p USING (dandomain_shop, order_id)
WHERE ABS(COALESCE(o.net_sales, 0) - COALESCE(p.net_sales, 0)) > 0.01
