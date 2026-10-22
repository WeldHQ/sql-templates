-- One row per day, campaign and creative set. A duplicate means the staging
-- de-duplication or the GROUP BY in core stopped matching the grain.
-- Returns zero rows when the grain holds.

SELECT date_day, campaign_id, ad_id, COUNT(*) AS row_count
FROM {{ ref('core_applovin__ad_performance_daily') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
