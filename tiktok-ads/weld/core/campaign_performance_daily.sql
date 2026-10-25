-- core.tiktok_ads.campaign_performance_daily
-- Daily campaign performance with the rates Ads Manager shows: CTR, CPC, CPM,
-- cost per conversion and Complete payment ROAS.
--
-- Grain: date_day x account_id x campaign_id. Currency: the advertiser's.
-- Depends on: core.tiktok_ads.ad_performance_daily
--
-- Built by summing ads; spend, impressions, clicks and conversions add up from
-- ad to campaign in TikTok's own reports. Reach does not (one person can see two
-- ads), so it is left out here rather than summed into a wrong number.
--
-- conversions add up the optimisation events of each ad group. In a campaign
-- whose ad groups optimise for different events, that total mixes event types,
-- exactly as the campaign row in Ads Manager does. Use
-- ad_group_performance_daily to keep them apart.
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

    SUM(spend)              AS spend,
    SUM(impressions)        AS impressions,
    SUM(clicks)             AS clicks,
    SUM(conversions)        AS conversions,
    SUM(conversion_value)   AS conversion_value,
    SUM(complete_payments)  AS complete_payments,
    SUM(app_purchases)      AS app_purchases,
    SUM(app_purchase_value) AS app_purchase_value,
    SUM(video_views)        AS video_views,
    COUNT(DISTINCT ad_id)   AS active_ads,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))         AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))               AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000   AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))          AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))     AS roas
FROM {{core.tiktok_ads.ad_performance_daily}}
GROUP BY 1, 2, 3, 4, 5, 6, 7
