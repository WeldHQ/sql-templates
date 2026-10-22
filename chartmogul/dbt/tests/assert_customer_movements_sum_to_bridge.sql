-- The customer drill-down must sum to the monthly MRR bridge, month by month.
-- Returns zero rows when they agree.

WITH customer_level AS (
    SELECT month, currency, SUM(net_mrr_movement) AS net_mrr_movement
    FROM {{ ref('core_chartmogul__customer_mrr_movements') }}
    GROUP BY 1, 2
),

bridge AS (
    SELECT month, currency, net_mrr_movement
    FROM {{ ref('core_chartmogul__mrr_movements') }}
)

SELECT
    COALESCE(c.month, b.month)       AS month,
    COALESCE(c.currency, b.currency) AS currency,
    c.net_mrr_movement               AS customer_level,
    b.net_mrr_movement               AS bridge_level
FROM customer_level c
FULL OUTER JOIN bridge b USING (month, currency)
WHERE ABS(COALESCE(c.net_mrr_movement, 0) - COALESCE(b.net_mrr_movement, 0)) > 0.01
