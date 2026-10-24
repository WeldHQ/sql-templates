-- Campaign spend must equal the sum of its ads' spend, day by day and per campaign.
-- Returns zero rows when they agree; a cent of tolerance absorbs rounding.

WITH ads AS (
    SELECT date_day, campaign_id, SUM(spend) AS spend
    FROM {{ ref('core_criteo__ad_performance_daily') }}
    GROUP BY 1, 2
),

campaigns AS (
    SELECT date_day, campaign_id, SUM(spend) AS spend
    FROM {{ ref('core_criteo__campaign_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(a.date_day, c.date_day)       AS date_day,
    COALESCE(a.campaign_id, c.campaign_id) AS campaign_id,
    a.spend AS ad_spend,
    c.spend AS campaign_spend
FROM ads a
FULL OUTER JOIN campaigns c USING (date_day, campaign_id)
WHERE ABS(COALESCE(a.spend, 0) - COALESCE(c.spend, 0)) > 0.01
