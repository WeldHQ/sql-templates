-- One row per day, account and ad. A duplicate means a report row was loaded
-- twice, or an entity table stopped being one row per account and id.
-- Returns zero rows when the grain holds.

SELECT date_day, account_id, ad_id, COUNT(*) AS row_count
FROM {{ ref('core_tiktok_ads__ad_performance_daily') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
