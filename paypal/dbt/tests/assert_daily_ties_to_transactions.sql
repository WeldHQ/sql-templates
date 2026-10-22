-- The daily summary must carry every balance-affecting transaction: totals per
-- currency agree between the two models. Returns zero rows when they agree.

WITH from_transactions AS (
    SELECT currency, SUM(net_amount) AS net
    FROM {{ ref('core_paypal__transactions') }}
    WHERE is_balance_affecting
    GROUP BY 1
),

from_daily AS (
    SELECT currency, SUM(net_balance_change) AS net
    FROM {{ ref('core_paypal__daily_balance_activity') }}
    GROUP BY 1
)

SELECT
    COALESCE(t.currency, d.currency) AS currency,
    t.net                            AS transactions_net,
    d.net                            AS daily_net
FROM from_transactions t
FULL OUTER JOIN from_daily d ON d.currency = t.currency
WHERE ABS(COALESCE(t.net, 0) - COALESCE(d.net, 0)) > 0.005
