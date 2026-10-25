-- Campaign spend and conversions must equal the sum over the account's ads, day
-- by day. Ads with an unknown campaign roll up into a NULL campaign on both
-- sides, so the totals still tie. Returns zero rows when they agree; a cent of
-- tolerance absorbs floating point rounding.

WITH ads AS (
    SELECT date_day, account_id, SUM(spend) AS spend, SUM(conversions) AS conversions
    FROM {{ ref('core_tiktok_ads__ad_performance_daily') }}
    GROUP BY 1, 2
),

campaigns AS (
    SELECT date_day, account_id, SUM(spend) AS spend, SUM(conversions) AS conversions
    FROM {{ ref('core_tiktok_ads__campaign_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(a.date_day, c.date_day)     AS date_day,
    COALESCE(a.account_id, c.account_id) AS account_id,
    a.spend       AS ad_spend,
    c.spend       AS campaign_spend,
    a.conversions AS ad_conversions,
    c.conversions AS campaign_conversions
FROM ads a
FULL OUTER JOIN campaigns c USING (date_day, account_id)
WHERE ABS(COALESCE(a.spend, 0) - COALESCE(c.spend, 0)) > 0.01
   OR ABS(COALESCE(a.conversions, 0) - COALESCE(c.conversions, 0)) > 0.001
