-- core_snapchat_ads__ad_squad_performance_daily
-- Daily performance per ad squad, Snapchat's ad set level, where targeting,
-- bidding, budget and the optimisation goal are set. Use it to compare squads
-- with different goals or bid strategies inside one campaign.
--
-- Grain: date_day x account_id x ad_squad_id. Currency: the ad account's.
-- Depends on: core.snapchat_ads.ad_performance_daily, staging.snapchat_ads.ad_squad
--
-- conversions are purchases, whatever the squad optimises for. A squad that
-- optimises for swipes or installs is judged here on purchases; compare it on
-- app_installs or clicks instead.
--
-- daily_budget is the current setting, not the budget on that day.

WITH squad_daily AS (
    SELECT
        date_day,
        account_id,
        account_name,
        currency,
        campaign_id,
        campaign_name,
        ad_squad_id,
        SUM(spend)            AS spend,
        SUM(impressions)      AS impressions,
        SUM(clicks)           AS clicks,
        SUM(conversions)      AS conversions,
        SUM(conversion_value) AS conversion_value,
        SUM(app_installs)     AS app_installs,
        SUM(video_views)      AS video_views,
        COUNT(DISTINCT ad_id) AS active_ads
    FROM {{ ref('core_snapchat_ads__ad_performance_daily') }}
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)

SELECT
    d.date_day,
    d.account_id,
    d.account_name,
    d.currency,
    d.campaign_id,
    d.campaign_name,
    d.ad_squad_id,
    sq.ad_squad_name,
    sq.optimization_goal,
    sq.bid_strategy,
    sq.billing_event,
    sq.placement,
    CAST(sq.daily_budget AS FLOAT64) AS daily_budget,

    d.spend,
    d.impressions,
    d.clicks,
    d.conversions,
    d.conversion_value,
    d.app_installs,
    d.video_views,
    d.active_ads,

    SAFE_DIVIDE(d.clicks, d.impressions)        AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)              AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000  AS cpm,
    SAFE_DIVIDE(d.spend, d.conversions)         AS cost_per_conversion,
    SAFE_DIVIDE(d.conversion_value, d.spend)    AS roas
FROM squad_daily d
-- One row per account and ad squad after staging: no fan-out.
LEFT JOIN {{ ref('stg_snapchat_ads__ad_squad') }} sq
    ON sq.account_id = d.account_id AND sq.ad_squad_id = d.ad_squad_id
