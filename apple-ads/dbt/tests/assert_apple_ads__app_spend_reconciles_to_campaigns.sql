-- Daily spend per app must add up to daily campaign spend. Campaigns without a
-- known app roll up into a NULL app on the app side, so the totals still tie.
-- Returns zero rows when they agree; a cent of tolerance absorbs rounding.

WITH campaigns AS (
    SELECT date_day, SUM(spend) AS spend
    FROM {{ ref('core_apple_ads__campaign_performance_daily') }}
    GROUP BY 1
),

apps AS (
    SELECT date_day, SUM(spend) AS spend
    FROM {{ ref('core_apple_ads__app_performance_daily') }}
    GROUP BY 1
)

SELECT
    COALESCE(c.date_day, a.date_day) AS date_day,
    c.spend AS campaign_spend,
    a.spend AS app_spend
FROM campaigns c
FULL OUTER JOIN apps a USING (date_day)
WHERE ABS(COALESCE(c.spend, 0) - COALESCE(a.spend, 0)) > 0.01
