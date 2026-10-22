-- Every shipped order is counted exactly once in fulfillment_by_day's SLA columns.
--
-- orders_first_shipped is attributed to the day and warehouse of each order's
-- first shipment and is then joined onto a spine built from shipments. If the two
-- disagree, orders fell outside the spine (a warehouse or date that only appears
-- on the order side) and the daily on-time rate is computed over the wrong
-- denominator.
--
-- Returns zero rows when they agree.

WITH from_orders AS (
    SELECT shiphero_account, COUNT(*) AS shipped_orders
    FROM {{ ref('core_shiphero__order_fulfillment') }}
    WHERE is_shipped
    GROUP BY 1
),

from_daily AS (
    SELECT shiphero_account, SUM(orders_first_shipped) AS shipped_orders
    FROM {{ ref('core_shiphero__fulfillment_by_day') }}
    GROUP BY 1
)

SELECT
    COALESCE(o.shiphero_account, d.shiphero_account) AS shiphero_account,
    o.shipped_orders AS order_level,
    d.shipped_orders AS daily_level
FROM from_orders o
FULL OUTER JOIN from_daily d
  ON d.shiphero_account = o.shiphero_account
WHERE COALESCE(o.shipped_orders, 0) <> COALESCE(d.shipped_orders, 0)
