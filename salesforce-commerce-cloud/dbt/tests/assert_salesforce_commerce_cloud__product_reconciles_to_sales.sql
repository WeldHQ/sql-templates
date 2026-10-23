-- The product model must sum to the order model, order by order. Commerce Cloud
-- allocates order-level promotions to lines itself, so net_sales should tie
-- exactly; a gap means a line failed to parse or the two models filter orders
-- differently.

WITH order_level AS (
    SELECT sfcc_instance, order_no, SUM(net_sales) AS net_sales
    FROM {{ ref('core_salesforce_commerce_cloud__sales_over_time') }}
    GROUP BY 1, 2
),

product_level AS (
    SELECT sfcc_instance, order_no, SUM(net_sales) AS net_sales
    FROM {{ ref('core_salesforce_commerce_cloud__product_sales_over_time') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(o.sfcc_instance, p.sfcc_instance) AS sfcc_instance,
    COALESCE(o.order_no, p.order_no)           AS order_no,
    o.net_sales AS order_level_net_sales,
    p.net_sales AS product_level_net_sales
FROM order_level o
FULL OUTER JOIN product_level p USING (sfcc_instance, order_no)
WHERE ABS(COALESCE(o.net_sales, 0) - COALESCE(p.net_sales, 0)) > 0.01
