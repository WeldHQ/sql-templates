-- core_apple_ads__app_performance_daily
-- Daily spend and results per promoted app, across all its campaigns: what an
-- app's Apple Ads budget bought each day.
--
-- Grain: date_day x account_id x app_id. Currency: the organization's.
-- Depends on: core.apple_ads.campaign_performance_daily
--
-- app_id is the App Store id (adamId) the campaign promotes. Campaigns missing
-- from the campaigns stream roll up under a NULL app. Rates are ratios of sums.

SELECT
    date_day,
    account_id,
    currency,
    app_id,

    COUNT(DISTINCT campaign_id) AS active_campaigns,
    SUM(spend)                  AS spend,
    SUM(impressions)            AS impressions,
    SUM(clicks)                 AS taps,
    SUM(conversions)            AS installs,
    SUM(new_downloads)          AS new_downloads,
    SUM(redownloads)            AS redownloads,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))       AS ttr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))             AS avg_cpt,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS avg_cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))        AS cost_per_install,
    SAFE_DIVIDE(SUM(conversions), SUM(clicks))       AS install_rate
FROM {{ ref('core_apple_ads__campaign_performance_daily') }}
GROUP BY 1, 2, 3, 4
