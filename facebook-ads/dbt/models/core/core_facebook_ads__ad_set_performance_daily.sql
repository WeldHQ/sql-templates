-- core_facebook_ads__ad_set_performance_daily
-- Daily ad set performance with its optimisation goal and attribution setting,
-- the Ads Manager "Ad sets" tab by day.
--
-- Grain: date_day x account_id x ad_set_id. Currency: the ad account's.
-- Depends on: core.facebook_ads.ad_performance_daily
--
-- attribution_setting is what the ad set optimises for in Ads Manager. The
-- conversion columns are reported under the windows the connector requests
-- (7-day click and 1-day view by default), which can differ from it; compare
-- the two before reading an ad set's ROAS against its own setting.

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    ad_set_id,
    ad_set_name,
    ad_set_optimization_goal,
    ad_set_attribution_setting,

    SUM(spend)                     AS spend,
    SUM(impressions)               AS impressions,
    SUM(clicks)                    AS clicks,
    SUM(conversions)               AS conversions,
    SUM(conversion_value)          AS conversion_value,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))       AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))             AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))        AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))   AS roas
FROM {{ ref('core_facebook_ads__ad_performance_daily') }}
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
