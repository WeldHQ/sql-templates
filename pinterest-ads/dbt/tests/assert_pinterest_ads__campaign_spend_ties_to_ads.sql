-- Daily spend per account must be the same in the campaign model as in the ad
-- model it is summed from. Ads with an unknown campaign roll up into a NULL
-- campaign on both sides, so the totals still tie.
-- Returns zero rows when they agree; a cent of tolerance absorbs float rounding.

WITH by_ad AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_pinterest_ads__ad_performance_daily') }}
    GROUP BY 1, 2
),

by_campaign AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_pinterest_ads__campaign_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(a.date_day, c.date_day)     AS date_day,
    COALESCE(a.account_id, c.account_id) AS account_id,
    a.spend AS ad_spend,
    c.spend AS campaign_spend
FROM by_ad a
FULL OUTER JOIN by_campaign c
    ON c.date_day = a.date_day
   AND COALESCE(c.account_id, '') = COALESCE(a.account_id, '')
WHERE ABS(COALESCE(a.spend, 0) - COALESCE(c.spend, 0)) > 0.01
