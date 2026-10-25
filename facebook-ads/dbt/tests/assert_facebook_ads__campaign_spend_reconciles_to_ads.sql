-- Campaign spend must equal the sum of its ads' spend, day by day and per account.
-- Returns zero rows when they agree; a cent of tolerance absorbs rounding.

WITH ads AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_facebook_ads__ad_performance_daily') }}
    GROUP BY 1, 2
),

campaigns AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_facebook_ads__campaign_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(a.date_day, c.date_day)     AS date_day,
    COALESCE(a.account_id, c.account_id) AS account_id,
    a.spend AS ad_spend,
    c.spend AS campaign_spend
FROM ads a
FULL OUTER JOIN campaigns c USING (date_day, account_id)
WHERE ABS(COALESCE(a.spend, 0) - COALESCE(c.spend, 0)) > 0.01
