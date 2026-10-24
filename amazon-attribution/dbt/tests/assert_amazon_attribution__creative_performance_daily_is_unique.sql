-- One row per day, profile, advertiser, campaign, ad group and creative. A duplicate
-- means a restated report row was kept twice, or the advertiser lookup stopped being
-- one row per name.
-- Returns zero rows when the grain holds.

SELECT date_day, profile_id, account_name, campaign_id, ad_group_id, ad_id, COUNT(*) AS row_count
FROM {{ ref('core_amazon_attribution__creative_performance_daily') }}
GROUP BY 1, 2, 3, 4, 5, 6
HAVING COUNT(*) > 1
