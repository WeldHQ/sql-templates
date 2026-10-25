-- core.pinterest_ads.campaign_performance_daily
-- Daily campaign performance with the rates Ads Manager shows: CTR, CPC, CPM,
-- cost per conversion and checkout ROAS.
--
-- Grain: date_day x account_id x campaign_id. Currency: the ad account's.
-- Depends on: core.pinterest_ads.ad_performance_daily
--
-- Summed from ads, so it uses the same definitions: conversions are all conversion
-- events, conversion_value is checkout value, Pinterest's default attribution
-- (30 day click, 30 day engagement, 1 day view). Rates are ratios of sums at this
-- grain; never average the daily rates.

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

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))             AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))                   AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000       AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))              AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))         AS roas,

    'pinterest_ads'                 AS source,
    SUM(earned_impressions)         AS earned_impressions,
    SUM(paid_outbound_clicks)       AS paid_outbound_clicks,
    SUM(signups)                    AS signups,
    SUM(checkout_value_click)       AS checkout_value_click,
    SUM(checkout_value_view)        AS checkout_value_view,
    COUNT(DISTINCT IF(impressions > 0, ad_id, NULL)) AS ads_with_impressions
FROM {{core.pinterest_ads.ad_performance_daily}}
GROUP BY 1, 2, 3, 4, 5, 6, 7
