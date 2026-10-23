-- Revenue and commission in the daily series must add up to the campaign totals.
--
-- A difference means conversions with no timestamp (they are in the campaign total
-- but cannot be placed on a day) or a spine that dropped days. Returns zero rows
-- when they agree; a cent of tolerance absorbs rounding.

WITH daily AS (
    SELECT grin_account, campaign_id, SUM(revenue) AS revenue, SUM(commission) AS commission
    FROM {{ ref('core_grin__conversions_by_day') }}
    GROUP BY 1, 2
),

campaigns AS (
    SELECT grin_account, campaign_id, revenue, commission
    FROM {{ ref('core_grin__campaign_performance') }}
)

SELECT
    COALESCE(d.grin_account, c.grin_account) AS grin_account,
    COALESCE(d.campaign_id, c.campaign_id)   AS campaign_id,
    d.revenue    AS daily_revenue,
    c.revenue    AS campaign_revenue,
    d.commission AS daily_commission,
    c.commission AS campaign_commission
FROM daily d
FULL OUTER JOIN campaigns c USING (grin_account, campaign_id)
WHERE ABS(COALESCE(d.revenue, 0)    - COALESCE(c.revenue, 0))    > 0.01
   OR ABS(COALESCE(d.commission, 0) - COALESCE(c.commission, 0)) > 0.01
