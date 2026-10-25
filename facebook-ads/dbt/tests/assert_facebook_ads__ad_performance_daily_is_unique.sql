-- One row per day, account and ad. A duplicate means the purchase tables were
-- joined before being reduced to one row per ad and day, or an entity table
-- stopped being one row per id. Returns zero rows when the grain holds.

SELECT date_day, account_id, ad_id, COUNT(*) AS row_count
FROM {{ ref('core_facebook_ads__ad_performance_daily') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
