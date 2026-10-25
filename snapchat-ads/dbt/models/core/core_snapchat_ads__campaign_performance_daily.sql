-- core_snapchat_ads__campaign_performance_daily
-- Daily campaign performance with the rates Ads Manager shows: CTR (swipe up
-- rate), CPC (cost per swipe up), CPM, cost per purchase and ROAS.
--
-- Grain: date_day x account_id x campaign_id. Currency: the ad account's.
-- Depends on: core.snapchat_ads.ad_performance_daily
--
-- Built by summing ads. Every ad belongs to one ad squad and one campaign, so the
-- sum matches the campaign row in Ads Manager, apart from ads whose campaign is
-- unknown: they land under a NULL campaign_id rather than being dropped.
--
-- Rates are ratios of sums at this grain. To report a week or a month, re-sum the
-- base columns and divide again; averaging the daily rates weights a quiet day the
-- same as a busy one.

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    campaign_objective,

    SUM(spend)            AS spend,
    SUM(impressions)      AS impressions,
    SUM(clicks)           AS clicks,
    SUM(conversions)      AS conversions,
    SUM(conversion_value) AS conversion_value,
    SUM(app_installs)     AS app_installs,
    SUM(video_views)      AS video_views,
    COUNT(DISTINCT ad_id) AS active_ads,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))         AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))               AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000   AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))          AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))     AS roas
FROM {{ ref('core_snapchat_ads__ad_performance_daily') }}
GROUP BY 1, 2, 3, 4, 5, 6, 7
