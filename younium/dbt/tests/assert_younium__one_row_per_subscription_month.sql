-- One row per month and order number in the drill-down.

SELECT month, order_number, COUNT(*) AS rows_at_grain
FROM {{ ref('core_younium__subscription_mrr_movements') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
