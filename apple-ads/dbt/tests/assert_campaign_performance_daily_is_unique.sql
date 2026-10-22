-- One row per day and campaign. A duplicate means staging stopped de-duplicating
-- re-synced days, or the campaigns stream stopped being one row per id.
-- Returns zero rows when the grain holds.

SELECT date_day, campaign_id, COUNT(*) AS row_count
FROM {{ ref('core_apple_ads__campaign_performance_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
