-- core.tiktok_ads.ad_performance_daily
-- Daily delivery and conversion results per ad, the Ads Manager "Ads" tab by day.
--
-- Grain: date_day x account_id x ad_id. Currency: the advertiser's.
-- Depends on: staging.tiktok_ads.ad_daily_report, .ad, .ad_group, .campaign, .advertiser
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the other paid
-- ads templates in this repo, so they can be stacked with UNION ALL.
-- In TikTok terms: account_id is the advertiser, the ad set level is the ad group.
--
-- conversions = TikTok's "Conversions" column: the number of times the ad's
-- optimisation event happened (a purchase for a purchase-optimised ad group, a
-- form submit for a lead ad group, an install for an app ad group), under the
-- attribution window set on the ad group. What it counts therefore differs per
-- ad group; optimization_goal and optimization_event say which.
--
-- conversion_value = the website Complete Payment value (count x average value).
-- It is a purchase value, not the value of the optimisation event, so ROAS here
-- is TikTok's "Complete payment ROAS". App purchases are kept apart in
-- app_purchases and app_purchase_value. For an app or lead account,
-- conversion_value will be 0 and ROAS empty.

SELECT
    r.date_day,
    r.account_id,
    adv.account_name,
    COALESCE(a.campaign_id, g.campaign_id) AS campaign_id,
    c.campaign_name,
    r.ad_id,
    a.ad_name,
    r.spend,
    r.impressions,
    r.clicks,
    CAST(r.conversions AS FLOAT64)         AS conversions,
    r.complete_payment_value               AS conversion_value,

    'tiktok_ads'                           AS source,
    adv.currency,
    a.ad_group_id,
    g.ad_group_name,
    c.campaign_objective,
    g.optimization_goal,
    g.optimization_event,
    r.reach,
    r.results,
    r.complete_payments,
    r.app_purchases,
    r.app_purchase_value,
    r.video_views,
    r.video_views_6s,
    r.video_completions,
    r.likes,
    r.comments,
    r.shares,
    r.follows,

    SAFE_DIVIDE(r.clicks, r.impressions)                  AS ctr,
    SAFE_DIVIDE(r.spend, r.clicks)                        AS cpc,
    SAFE_DIVIDE(r.spend, r.impressions) * 1000            AS cpm,
    SAFE_DIVIDE(r.spend, r.conversions)                   AS cost_per_conversion,
    SAFE_DIVIDE(r.complete_payment_value, r.spend)        AS roas
FROM {{staging.tiktok_ads.ad_daily_report}} r
-- Entity tables are one row per advertiser and id after staging, so these joins
-- cannot fan out. LEFT JOINs: an ad missing from the entity streams keeps its
-- spend, with NULL names.
LEFT JOIN {{staging.tiktok_ads.advertiser}} adv
    ON adv.account_id = r.account_id
LEFT JOIN {{staging.tiktok_ads.ad}} a
    ON a.account_id = r.account_id AND a.ad_id = r.ad_id
LEFT JOIN {{staging.tiktok_ads.ad_group}} g
    ON g.account_id = a.account_id AND g.ad_group_id = a.ad_group_id
LEFT JOIN {{staging.tiktok_ads.campaign}} c
    ON c.account_id = a.account_id AND c.campaign_id = COALESCE(a.campaign_id, g.campaign_id)
