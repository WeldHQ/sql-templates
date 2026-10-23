-- sales_over_time is one row per order. A duplicate means the staging dedupe
-- failed or the item pre-aggregation fanned out.

SELECT adobe_commerce_store, order_id, COUNT(*) AS n
FROM {{ ref('core_adobe_commerce__sales_over_time') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
