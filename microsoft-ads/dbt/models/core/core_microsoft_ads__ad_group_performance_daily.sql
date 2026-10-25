-- core_microsoft_ads__ad_group_performance_daily
-- Daily ad group performance, the Microsoft Advertising "Ad groups" report by day.
--
-- Grain: date_day x account_id x ad_group_id. Currency: the account's.
-- Depends on: staging.microsoft_ads.ad_group_performance_daily_report,
-- .ad_group, .campaign, .account
--
-- Read from the ad group report rather than summed from ads, so ad groups whose
-- ads were deleted still carry their full delivery. Performance Max has no ad
-- groups and is not in it.
--
-- conversions counts the conversion goals set to "Include in conversions",
-- under each goal's own conversion window, dated on the day of the ad click.
-- conversion_value is the matching revenue. all_conversions and all_revenue count
-- every goal, including those left out of conversions. View-through
-- conversions are also carried on their own.

WITH daily AS (
    SELECT
        date_day,
        account_id,
        ad_group_id,
        MAX(campaign_id)              AS campaign_id,
        MAX(currency)                 AS report_currency,
        SUM(spend)                    AS spend,
        SUM(impressions)              AS impressions,
        SUM(clicks)                   AS clicks,
        SUM(conversions)              AS conversions,
        SUM(revenue)                  AS conversion_value,
        SUM(all_conversions)          AS all_conversions,
        SUM(all_revenue)              AS all_revenue,
        SUM(view_through_conversions) AS view_through_conversions
    FROM {{ ref('stg_microsoft_ads__ad_group_performance_daily_report') }}
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
    d.all_conversions,
    d.all_revenue,
    d.view_through_conversions
FROM daily d
LEFT JOIN {{ ref('stg_microsoft_ads__ad_group') }} g   ON g.ad_group_id = d.ad_group_id
LEFT JOIN {{ ref('stg_microsoft_ads__campaign') }} c   ON c.campaign_id = d.campaign_id
LEFT JOIN {{ ref('stg_microsoft_ads__account') }}  acc ON acc.account_id = d.account_id
