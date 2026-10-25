-- core.microsoft_ads.campaign_performance_daily
-- Daily campaign performance with the rates the Microsoft Advertising UI shows:
-- CTR, CPC, CPM, cost per conversion and ROAS.
--
-- Grain: date_day x account_id x campaign_id. Currency: the account's.
-- Depends on: staging.microsoft_ads.campaign_performance_daily_report,
-- .campaign, .account
--
-- Read from the campaign report, not summed from ad_performance_daily: the ad
-- report has no rows for Performance Max, so only the campaign report ties to
-- account spend.
--
-- conversions counts the conversion goals set to "Include in conversions",
-- under each goal's own conversion window, dated on the day of the ad click.
-- conversion_value is the matching revenue. all_conversions and all_revenue count
-- every goal, including those left out of conversions. View-through
-- conversions are also carried on their own.
--
-- Rates are ratios of sums; to report a week or a month, re-sum the base
-- columns and divide again.

WITH daily AS (
    SELECT
        date_day,
        account_id,
        campaign_id,
        MAX(currency)                 AS report_currency,
        SUM(spend)                    AS spend,
        SUM(impressions)              AS impressions,
        SUM(clicks)                   AS clicks,
        SUM(conversions)              AS conversions,
        SUM(revenue)                  AS conversion_value,
        SUM(all_conversions)          AS all_conversions,
        SUM(all_revenue)              AS all_revenue,
        SUM(view_through_conversions) AS view_through_conversions
    FROM {{staging.microsoft_ads.campaign_performance_daily_report}}
    GROUP BY 1, 2, 3
)

SELECT
    d.date_day,
    d.account_id,
    acc.account_name,
    COALESCE(d.report_currency, acc.currency)    AS currency,
    d.campaign_id,
    c.campaign_name,
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
    c.campaign_status,
    d.all_conversions,
    d.all_revenue,
    d.view_through_conversions
FROM daily d
LEFT JOIN {{staging.microsoft_ads.campaign}} c   ON c.campaign_id = d.campaign_id
LEFT JOIN {{staging.microsoft_ads.account}}  acc ON acc.account_id = d.account_id
