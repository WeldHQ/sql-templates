-- core.google_ads.ad_performance_daily
-- Daily delivery and conversions per ad, the Google Ads "Ads" view by day.
--
-- Grain: date_day x account_id x ad_id (ad_group_id is carried in the key as
-- well, because Google identifies an ad by ad group and ad ID together).
-- Currency: the account's. Depends on: staging.google_ads.ad_stats, .ad,
-- .ad_group, .campaign, .account
--
-- The leading columns follow the cross-channel ad contract shared with the other
-- paid ads templates in this repo, so the models can be stacked with UNION ALL.
--
-- conversions is Google's "Conversions" column: conversion actions marked as
-- primary ("Include in Conversions"), each under its own attribution model and
-- click-through window, dated on the day of the ad interaction. It can be
-- fractional under data-driven attribution. conversion_value is the matching
-- value. "All conversions" is not in the standard report; view-through
-- conversions are carried separately and are not part of conversions.
--
-- Covers ads only. Performance Max, Smart and some App campaigns have no ad
-- level rows, so this model sums to less than campaign_performance_daily for
-- accounts that run them.

WITH daily AS (
    -- The report is split by device and ad network; collapse to one row per ad.
    SELECT
        date_day,
        account_id,
        campaign_id,
        ad_group_id,
        ad_id,
        MAX(account_name)             AS report_account_name,
        MAX(campaign_name)            AS report_campaign_name,
        MAX(ad_group_name)            AS report_ad_group_name,
        MAX(ad_name)                  AS report_ad_name,
        SUM(spend)                    AS spend,
        SUM(impressions)              AS impressions,
        SUM(clicks)                   AS clicks,
        SUM(interactions)             AS interactions,
        SUM(conversions)              AS conversions,
        SUM(conversion_value)         AS conversion_value,
        SUM(view_through_conversions) AS view_through_conversions,
        SUM(video_views)              AS video_views
    FROM {{staging.google_ads.ad_stats}}
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    d.date_day,
    d.account_id,
    COALESCE(acc.account_name, d.report_account_name)  AS account_name,
    acc.currency,
    d.campaign_id,
    COALESCE(c.campaign_name, d.report_campaign_name)  AS campaign_name,
    d.ad_group_id,
    COALESCE(g.ad_group_name, d.report_ad_group_name)  AS ad_group_name,
    d.ad_id,
    COALESCE(a.ad_name, d.report_ad_name)              AS ad_name,
    d.spend,
    d.impressions,
    d.clicks,
    d.conversions,
    d.conversion_value,
    SAFE_DIVIDE(d.clicks, d.impressions)               AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)                     AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000         AS cpm,
    SAFE_DIVIDE(d.spend, d.conversions)                AS cost_per_conversion,
    SAFE_DIVIDE(d.conversion_value, d.spend)           AS roas,

    'google_ads'                                       AS source,
    c.channel_type                                     AS campaign_channel_type,
    a.ad_type,
    d.interactions,
    d.view_through_conversions,
    d.video_views,
    a.final_url,
    -- Google applies the most specific suffix that is set: ad, then ad group,
    -- then campaign, then account.
    COALESCE(a.final_url_suffix, g.final_url_suffix,
             c.final_url_suffix, acc.final_url_suffix) AS final_url_suffix
FROM daily d
-- Entity tables are one row per key after staging, so these joins cannot fan out.
-- LEFT JOINs: a removed ad keeps its spend, with report names as a fallback.
LEFT JOIN {{staging.google_ads.ad}}       a
       ON a.account_id = d.account_id AND a.ad_group_id = d.ad_group_id AND a.ad_id = d.ad_id
LEFT JOIN {{staging.google_ads.ad_group}} g
       ON g.account_id = d.account_id AND g.ad_group_id = d.ad_group_id
LEFT JOIN {{staging.google_ads.campaign}} c
       ON c.account_id = d.account_id AND c.campaign_id = d.campaign_id
LEFT JOIN {{staging.google_ads.account}}  acc
       ON acc.account_id = d.account_id
