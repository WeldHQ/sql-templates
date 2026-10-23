-- One row per day, profile, advertiser and campaign.
-- Returns zero rows when the grain holds.

SELECT date_day, profile_id, advertiser_name, campaign_id, COUNT(*) AS row_count
FROM {{ ref('core_amazon_attribution__campaign_performance_daily') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
