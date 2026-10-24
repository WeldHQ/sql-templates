-- core.apple_ads.campaign_performance_daily
-- Daily campaign performance, the Apple Ads Campaigns view by day, with the rates
-- Apple shows: TTR, average CPT, average CPM, cost per install and install rate.
--
-- Grain: date_day x account_id x campaign_id. Currency: the organization's.
-- Depends on: staging.apple_ads.campaign_report, .campaign
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the other paid
-- ads templates in this repo, so they can be stacked with UNION ALL.
--
-- The connector syncs performance at campaign level only, so this is the lowest
-- level available: ad_id and ad_name are NULL. account_id is the Apple Ads
-- organization; its name is not synced, so account_name is NULL.
-- clicks = taps. conversions = tap-through installs (new downloads plus
-- redownloads, 30-day attribution window). Apple Ads reports no revenue, so
-- conversion_value is NULL.
--
-- Rates are ratios of sums at this grain. To report a week or a month, re-sum the
-- base columns and divide again.

SELECT
    r.date_day,
    c.account_id,
    CAST(NULL AS STRING)                              AS account_name,
    r.campaign_id,
    COALESCE(c.campaign_name, r.campaign_name)        AS campaign_name,
    CAST(NULL AS STRING)                              AS ad_id,
    CAST(NULL AS STRING)                              AS ad_name,
    r.spend,
    r.impressions,
    r.taps                                            AS clicks,
    r.installs                                        AS conversions,
    CAST(NULL AS NUMERIC)                             AS conversion_value,

    'apple_ads'                                       AS source,
    r.currency,
    c.app_id,
    c.ad_channel_type,
    c.supply_sources,
    c.display_status,
    r.country_or_region,
    r.new_downloads,
    r.redownloads,

    SAFE_DIVIDE(r.taps, r.impressions)                AS ttr,
    SAFE_DIVIDE(r.spend, r.taps)                      AS avg_cpt,
    SAFE_DIVIDE(r.spend, r.impressions) * 1000        AS avg_cpm,
    SAFE_DIVIDE(r.spend, r.installs)                  AS cost_per_install,
    SAFE_DIVIDE(r.installs, r.taps)                   AS install_rate
FROM {{staging.apple_ads.campaign_report}} r
-- campaign is one row per id after staging, so the join cannot fan out.
-- LEFT JOIN: a campaign missing from the campaigns stream keeps its spend.
LEFT JOIN {{staging.apple_ads.campaign}} c ON c.campaign_id = r.campaign_id
