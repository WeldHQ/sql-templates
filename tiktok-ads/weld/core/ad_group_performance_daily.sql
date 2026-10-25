-- core.tiktok_ads.ad_group_performance_daily
-- Daily performance per ad group, labelled with the optimisation goal and event
-- that define what "conversions" means for it. This is the level to read cost
-- per conversion at: within one ad group the conversions are a single event type.
--
-- Grain: date_day x account_id x ad_group_id. Currency: the advertiser's.
-- Depends on: core.tiktok_ads.ad_performance_daily, staging.tiktok_ads.ad_group
--
-- Reach is left out: it does not add up across ads.
-- budget is the current setting, not the budget on that day; budget_mode says
-- whether it is daily or lifetime.

WITH group_daily AS (
    SELECT
        date_day,
        account_id,
        account_name,
        currency,
        campaign_id,
        campaign_name,
        ad_group_id,
        SUM(spend)              AS spend,
        SUM(impressions)        AS impressions,
        SUM(clicks)             AS clicks,
        SUM(conversions)        AS conversions,
        SUM(conversion_value)   AS conversion_value,
        SUM(complete_payments)  AS complete_payments,
        SUM(app_purchases)      AS app_purchases,
        SUM(app_purchase_value) AS app_purchase_value,
        SUM(video_views)        AS video_views,
        COUNT(DISTINCT ad_id)   AS active_ads
    FROM {{core.tiktok_ads.ad_performance_daily}}
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)

SELECT
    d.date_day,
    d.account_id,
    d.account_name,
    d.currency,
    d.campaign_id,
    d.campaign_name,
    d.ad_group_id,
    g.ad_group_name,
    g.optimization_goal,
    g.optimization_event,
    g.billing_event,
    g.bid_type,
    g.placement_type,
    g.budget_mode,
    g.budget,

    d.spend,
    d.impressions,
    d.clicks,
    d.conversions,
    d.conversion_value,
    d.complete_payments,
    d.app_purchases,
    d.app_purchase_value,
    d.video_views,
    d.active_ads,

    SAFE_DIVIDE(d.clicks, d.impressions)        AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)              AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000  AS cpm,
    SAFE_DIVIDE(d.spend, d.conversions)         AS cost_per_conversion,
    SAFE_DIVIDE(d.conversion_value, d.spend)    AS roas
FROM group_daily d
-- One row per advertiser and ad group after staging: no fan-out.
LEFT JOIN {{staging.tiktok_ads.ad_group}} g
    ON g.account_id = d.account_id AND g.ad_group_id = d.ad_group_id
