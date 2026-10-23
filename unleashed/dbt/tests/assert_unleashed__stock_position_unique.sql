-- stock_position is unique on product. Returns zero rows when it holds.

SELECT product_id, COUNT(*) AS n
FROM {{ ref('core_unleashed__stock_position') }}
GROUP BY 1
HAVING COUNT(*) > 1
