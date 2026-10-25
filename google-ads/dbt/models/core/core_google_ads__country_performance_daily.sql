-- core_google_ads__country_performance_daily
-- Daily campaign performance by country, Google's "Locations > user locations"
-- report with names attached.
--
-- Grain: date_day x account_id x campaign_id x country_criterion_id x location_type.
-- Currency: the account's. Depends on: staging.google_ads.ad_group_country_stats,
-- .geo_target, .campaign, .account
--
-- location_type says how the user matched the country: LOCATION_OF_PRESENCE
-- (physically there) or AREA_OF_INTEREST (searching for it). It stays in the
-- grain. Filter to one type for a "spend by country" view; check the total
-- against the campaign report before summing both types together.
--
-- Built from ad group rows, so campaigns without ad groups (Performance Max)
-- are not in it.

WITH daily AS (
    SELECT
        date_day,
        account_id,
        campaign_id,
        country_criterion_id,
        location_type,
        MAX(campaign_name)    AS report_campaign_name,
        SUM(spend)            AS spend,
        SUM(impressions)      AS impressions,
        SUM(clicks)           AS clicks,
        SUM(conversions)      AS conversions,
        SUM(conversion_value) AS conversion_value
    FROM {{ ref('stg_google_ads__ad_group_country_stats') }}
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    d.date_day,
    d.account_id,
    acc.account_name,
    acc.currency,
    d.campaign_id,
    COALESCE(c.campaign_name, d.report_campaign_name) AS campaign_name,
    d.country_criterion_id,
    geo.country_code,
    geo.geo_target_name                               AS country_name,
    d.location_type,
    d.spend,
    d.impressions,
    d.clicks,
    d.conversions,
    d.conversion_value,
    SAFE_DIVIDE(d.clicks, d.impressions)              AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)                    AS cpc,
    SAFE_DIVIDE(d.spend, d.conversions)               AS cost_per_conversion,
    SAFE_DIVIDE(d.conversion_value, d.spend)          AS roas
FROM daily d
-- geo_target and the entity tables are one row per key, so no fan-out.
LEFT JOIN {{ ref('stg_google_ads__geo_target') }} geo
       ON geo.geo_target_id = d.country_criterion_id
LEFT JOIN {{ ref('stg_google_ads__campaign') }}   c
       ON c.account_id = d.account_id AND c.campaign_id = d.campaign_id
LEFT JOIN {{ ref('stg_google_ads__account') }}    acc
       ON acc.account_id = d.account_id
