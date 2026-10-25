-- Ad level spend is a subset of campaign level spend: Performance Max only
-- appears in the campaign report. So per day and account, neither ad nor ad
-- group spend may exceed campaign spend. A breach means a report was double
-- counted. Returns zero rows when it holds; a cent of tolerance absorbs rounding.

WITH campaigns AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_microsoft_ads__campaign_performance_daily') }}
    GROUP BY 1, 2
),

lower_levels AS (
    SELECT 'ad' AS level, date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_microsoft_ads__ad_performance_daily') }}
    GROUP BY 1, 2, 3
    UNION ALL
    SELECT 'ad_group' AS level, date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_microsoft_ads__ad_group_performance_daily') }}
    GROUP BY 1, 2, 3
)

SELECT
    l.level,
    l.date_day,
    l.account_id,
    l.spend               AS level_spend,
    COALESCE(c.spend, 0)  AS campaign_spend
FROM lower_levels l
LEFT JOIN campaigns c USING (date_day, account_id)
WHERE l.spend > COALESCE(c.spend, 0) + 0.01
