-- One row per order line in product_sales_over_time. Staging keeps the latest copy
-- of each line; a duplicate here means that de-duplication was removed or the line
-- ID repeats across orders.

SELECT dandomain_shop, order_line_id, COUNT(*) AS n
FROM {{ ref('core_dandomain_webshop__product_sales_over_time') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
