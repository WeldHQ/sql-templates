-- One row per day x store x order x row type in sales_over_time. A duplicate means
-- the order or refund stream holds the same id twice, which would double the
-- order's money in every report.

SELECT date, bigcommerce_store, order_id, row_type, COUNT(*) AS n
FROM {{ ref('core_bigcommerce__sales_over_time') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
