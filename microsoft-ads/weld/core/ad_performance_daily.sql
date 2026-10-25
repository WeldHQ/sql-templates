-- core.microsoft_ads.ad_performance_daily
-- Daily delivery and conversions per ad, the Microsoft Advertising "Ads" report
-- by day.
--
-- Grain: date_day x account_id x ad_id. Currency: the account's.
-- Depends on: staging.microsoft_ads.ad_performance_daily_report, .ad, .ad_group,
-- .campaign, .account
--
-- The leading columns follow the cross-channel ad contract shared with the other
-- paid ads templates in this repo, so the models can be stacked with UNION ALL.
--
-- conversions counts the conversion goals set to "Include in conversions",
-- under each goal's own conversion window, dated on the day of the ad click.
-- conversion_value is the matching revenue. all_conversions and all_revenue count
-- every goal, including those left out of conversions. View-through
-- conversions are also carried on their own.
--
-- Covers ads only: Performance Max asset groups have no ad level rows, so this
-- model sums to less than campaign_performance_daily in accounts that run them.

WITH daily AS (
    -- The report splits each ad and day by device, network, match type and more;
    -- collapse to one row per ad. campaign and ad group never change for an ad.
    SELECT
        date_day,
        account_id,
        ad_id,
        MAX(campaign_id)              AS campaign_id,
        MAX(ad_group_id)              AS ad_group_id,
        MAX(currency)                 AS report_currency,
        SUM(spend)                    AS spend,
        SUM(impressions)              AS impressions,
        SUM(clicks)                   AS clicks,
        SUM(conversions)              AS conversions,
        SUM(revenue)                  AS conversion_value,
        SUM(all_conversions)          AS all_conversions,
        SUM(all_revenue)              AS all_revenue,
        SUM(view_through_conversions) AS view_through_conversions
    FROM {{staging.microsoft_ads.ad_performance_daily_report}}
    GROUP BY 1, 2, 3
)

SELECT
    d.date_day,
    d.account_id,
    acc.account_name,
    COALESCE(d.report_currency, acc.currency)    AS currency,
    d.campaign_id,
    c.campaign_name,
    d.ad_group_id,
    g.ad_group_name,
    d.ad_id,
    a.ad_name,
    d.spend,
    d.impressions,
    d.clicks,
    d.conversions,
    d.conversion_value,
    SAFE_DIVIDE(d.clicks, d.impressions)         AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)               AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000   AS cpm,
    SAFE_DIVIDE(d.spend, d.conversions)          AS cost_per_conversion,
    SAFE_DIVIDE(d.conversion_value, d.spend)     AS roas,

    'microsoft_ads'                              AS source,
    c.campaign_type,
    a.final_url,
    d.all_conversions,
    d.all_revenue,
    d.view_through_conversions
FROM daily d
-- Entity tables are one row per id after staging, so these joins cannot fan out.
-- LEFT JOINs: a deleted ad keeps its spend, with NULL names.
LEFT JOIN {{staging.microsoft_ads.ad}}       a   ON a.ad_id = d.ad_id
LEFT JOIN {{staging.microsoft_ads.ad_group}} g   ON g.ad_group_id = d.ad_group_id
LEFT JOIN {{staging.microsoft_ads.campaign}} c   ON c.campaign_id = d.campaign_id
LEFT JOIN {{staging.microsoft_ads.account}}  acc ON acc.account_id = d.account_id
