-- core.amazon_attribution.creative_performance_daily
-- Daily click-throughs and Amazon conversions per Attribution creative: what your
-- off-Amazon traffic (search, social, email, influencers) did once it reached Amazon.
--
-- Grain: date_day x profile_id x advertiser x campaign_id x ad_group_id x ad_id.
-- Currency: the profile's.
-- Depends on: staging.amazon_attribution.creative_performance, .advertiser, .profile
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the paid ads
-- templates in this repo. Amazon Attribution only sees what happens after the click,
-- so some of them are honestly empty:
--   spend, impressions        NULL. Spend and impressions live in the ad platform
--                             that served the ad; join them from that template.
--   campaign_name, ad_name    NULL. The report carries ids only.
--   account                   the Attribution advertiser.
--   ad_id                     the Attribution creative (tag); 'unknown' for clicks
--                             Amazon could not tie to a creative.
--   clicks                    click-throughs to Amazon.
--   conversions, value        total purchases and sales: promoted products plus
--                             brand halo, 14 day window, dated on the click.

WITH advertiser AS (
    -- The report names the advertiser but carries no id. Resolve it within the
    -- profile, one id per name, so the join cannot fan out.
    SELECT profile_id, advertiser_name, MIN(advertiser_id) AS advertiser_id
    FROM {{staging.amazon_attribution.advertiser}}
    GROUP BY 1, 2
)

SELECT
    p.date_day,
    a.advertiser_id                    AS account_id,
    p.advertiser_name                  AS account_name,
    p.campaign_id,
    CAST(NULL AS STRING)               AS campaign_name,
    p.creative_id                      AS ad_id,
    CAST(NULL AS STRING)               AS ad_name,
    CAST(NULL AS NUMERIC)              AS spend,
    CAST(NULL AS INT64)                AS impressions,
    p.click_throughs                   AS clicks,
    p.total_purchases                  AS conversions,
    p.total_sales                      AS conversion_value,

    'amazon_attribution'               AS source,
    pr.currency,
    p.profile_id,
    pr.profile_name,
    p.ad_group_id,
    p.publisher,
    p.detail_page_views,
    p.add_to_carts,
    p.purchases,
    p.units_sold,
    p.sales,
    p.total_detail_page_views,
    p.total_add_to_carts,
    p.total_purchases,
    p.total_units_sold,
    p.total_sales,
    p.kenp_pages_read,
    p.kenp_royalties
FROM {{staging.amazon_attribution.creative_performance}} p
-- Both lookups are one row per key, so these joins cannot fan out.
LEFT JOIN advertiser a
    ON a.profile_id = p.profile_id AND a.advertiser_name = p.advertiser_name
LEFT JOIN {{staging.amazon_attribution.profile}} pr
    ON pr.profile_id = p.profile_id
