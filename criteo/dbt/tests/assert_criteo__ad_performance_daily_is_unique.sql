-- One row per day, campaign, ad set and ad. The placeholder ad "-1" repeats per
-- ad set, which is why the ad set is part of the key. A duplicate means staging
-- stopped de-duplicating re-synced days, or an entity table stopped being one
-- row per id. Returns zero rows when the grain holds.

SELECT date_day, campaign_id, adset_id, ad_id, COUNT(*) AS row_count
FROM {{ ref('core_criteo__ad_performance_daily') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
