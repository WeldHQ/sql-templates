-- The per-subscription drill-down must sum to the monthly CMRR bridge.
-- Returns zero rows when they agree.

WITH subscription_level AS (
    SELECT month, SUM(net_cmrr_change) AS net_cmrr_change
    FROM {{ ref('core_younium__subscription_mrr_movements') }}
    GROUP BY 1
),

bridge AS (
    SELECT month, net_cmrr_change
    FROM {{ ref('core_younium__mrr_movements') }}
)

SELECT
    COALESCE(s.month, b.month) AS month,
    s.net_cmrr_change          AS subscription_level,
    b.net_cmrr_change          AS bridge_level
FROM subscription_level s
FULL OUTER JOIN bridge b USING (month)
WHERE ABS(COALESCE(s.net_cmrr_change, 0) - COALESCE(b.net_cmrr_change, 0)) > 0.01
