-- core_criteo__campaign_performance_daily
-- Daily campaign performance with the rates the Criteo UI shows: CTR, CPC, CPM,
-- cost per order (CPO), conversion rate and ROAS.
--
-- Grain: date_day x account_id x campaign_id. Currency: the connector setting.
-- Depends on: core.criteo.ad_performance_daily
--
-- Built from the ad report, including the "-1" placeholder ad, so spend ties to
-- the campaign totals in Criteo. Rates are ratios of sums at this grain. To
-- report a week or a month, re-sum the base columns and divide again; averaging
-- the daily rates weights a quiet day the same as a busy one.

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    campaign_goal,

    SUM(spend)            AS spend,
    SUM(impressions)      AS impressions,
    SUM(clicks)           AS clicks,
    SUM(conversions)      AS conversions,
    SUM(conversion_value) AS conversion_value,
    COUNT(DISTINCT IF(ad_id != '-1', ad_id, NULL)) AS active_ads,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))       AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))             AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))        AS cost_per_order,
    SAFE_DIVIDE(SUM(conversions), SUM(clicks))       AS conversion_rate,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))   AS roas
FROM {{ ref('core_criteo__ad_performance_daily') }}
GROUP BY 1, 2, 3, 4, 5, 6, 7
