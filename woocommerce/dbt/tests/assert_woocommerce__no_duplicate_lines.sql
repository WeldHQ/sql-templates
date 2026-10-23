-- product_sales_over_time is one row per product line. A duplicate means a
-- staging dedupe or a product/SKU join fanned out (for example two _sku meta rows
-- surviving for one product).

SELECT woocommerce_store, order_item_id, COUNT(*) AS n
FROM {{ ref('core_woocommerce__product_sales_over_time') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
