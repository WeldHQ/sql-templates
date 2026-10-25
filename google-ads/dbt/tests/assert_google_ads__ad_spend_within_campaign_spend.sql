-- Ad level spend is a subset of campaign level spend: campaigns without ads
-- (Performance Max, Smart) only appear in the campaign report. So per day and
-- account, ad spend must never exceed campaign spend. A breach means a report
-- was double counted or a retracted row slipped through.
-- Returns zero rows when it holds; a cent of tolerance absorbs rounding.

WITH ads AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_google_ads__ad_performance_daily') }}
    GROUP BY 1, 2
),

campaigns AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_google_ads__campaign_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    a.date_day,
    a.account_id,
    a.spend               AS ad_spend,
    COALESCE(c.spend, 0)  AS campaign_spend
FROM ads a
LEFT JOIN campaigns c USING (date_day, account_id)
WHERE a.spend > COALESCE(c.spend, 0) + 0.01
