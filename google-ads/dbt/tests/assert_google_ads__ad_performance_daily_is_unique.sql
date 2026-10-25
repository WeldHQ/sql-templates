-- One row per day, account, ad group and ad. A duplicate means an entity table
-- stopped being one row per key, or the report was not collapsed over device
-- and network. Returns zero rows when the grain holds.

SELECT date_day, account_id, ad_group_id, ad_id, COUNT(*) AS row_count
FROM {{ ref('core_google_ads__ad_performance_daily') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
