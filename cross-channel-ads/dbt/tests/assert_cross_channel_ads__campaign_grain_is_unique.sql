-- One row per day, platform, account and campaign. A duplicate means a platform
-- branch was added twice, or a platform model stopped being one row per campaign
-- and currency.
-- Returns zero rows when the grain holds.

SELECT date_day, source, account_id, campaign_id, COUNT(*) AS row_count
FROM {{ ref('core_cross_channel_ads__campaign_performance_daily') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
