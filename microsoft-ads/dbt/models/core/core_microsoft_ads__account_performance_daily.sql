-- core_microsoft_ads__account_performance_daily
-- Daily totals per account, the Microsoft Advertising "Accounts" view by day,
-- with the account's time zone.
--
-- Grain: date_day x account_id. Currency: the account's.
-- Depends on: core.microsoft_ads.campaign_performance_daily, staging.microsoft_ads.account
--
-- Summed from the campaign model, which covers every campaign type. Dates are
-- the account's own time zone (time_zone), as Microsoft reports them; accounts
-- in different time zones do not share a day boundary.

SELECT
    p.date_day,
    p.account_id,
    p.account_name,
    acc.time_zone,
    p.currency,
    SUM(p.spend)                    AS spend,
    SUM(p.impressions)              AS impressions,
    SUM(p.clicks)                   AS clicks,
    SUM(p.conversions)              AS conversions,
    SUM(p.conversion_value)         AS conversion_value,
    SUM(p.all_conversions)          AS all_conversions,
    SUM(p.all_revenue)              AS all_revenue,
    SUM(p.view_through_conversions) AS view_through_conversions,
    COUNT(DISTINCT p.campaign_id)   AS active_campaigns,
    SAFE_DIVIDE(SUM(p.clicks), SUM(p.impressions))           AS ctr,
    SAFE_DIVIDE(SUM(p.spend), SUM(p.clicks))                 AS cpc,
    SAFE_DIVIDE(SUM(p.spend), SUM(p.impressions)) * 1000     AS cpm,
    SAFE_DIVIDE(SUM(p.spend), SUM(p.conversions))            AS cost_per_conversion,
    SAFE_DIVIDE(SUM(p.conversion_value), SUM(p.spend))       AS roas
FROM {{ ref('core_microsoft_ads__campaign_performance_daily') }} p
-- One row per account after staging, so no fan-out.
LEFT JOIN {{ ref('stg_microsoft_ads__account') }} acc ON acc.account_id = p.account_id
GROUP BY 1, 2, 3, 4, 5
