-- core.cross_channel_ads.campaign_performance_daily
-- Paid media from every ad platform in one table: spend, delivery, conversions
-- and conversion value per campaign and day, with the same rates on every row.
--
-- Grain: date_day x source x account_id x campaign_id. Currency: the ad account's,
-- carried on every row. Nothing here converts currencies; see the README before
-- adding accounts that bill in different currencies together.
-- Depends on: core.<platform>.campaign_performance_daily for each platform below.
--
-- KEEP ONLY THE PLATFORMS YOU SYNC. Each UNION ALL branch reads one platform's
-- campaign model; a branch whose model does not exist in your project fails the
-- whole query. Delete the branches you do not need (and their UNION ALL).
--
-- What "conversions" means differs by platform, because each platform counts its
-- own primary result: purchases on Meta, the conversion goals marked "Include in
-- conversions" on Google and Microsoft, website conversions on LinkedIn, the
-- optimisation event on TikTok, installs on Apple. The README has the full list.
-- Summing conversions across platforms adds different things together; compare
-- spend, impressions and clicks across platforms, and conversions within one.
--
-- The campaign models are read rather than the ad models: Performance Max and
-- similar campaign types have no ad-level rows on Google and Microsoft, so only
-- the campaign level carries all of their spend.

WITH campaigns AS (
    SELECT
        'google_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.google_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'facebook_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.facebook_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'microsoft_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.microsoft_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'linkedin_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.linkedin_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'tiktok_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.tiktok_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'pinterest_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.pinterest_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'snapchat_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.snapchat_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'reddit_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.reddit_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'apple_ads' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.apple_ads.campaign_performance_daily}}

    UNION ALL

    SELECT
        'criteo' AS source,
        CAST(date_day AS DATE)             AS date_day,
        CAST(account_id AS STRING)         AS account_id,
        CAST(account_name AS STRING)       AS account_name,
        CAST(currency AS STRING)           AS currency,
        CAST(campaign_id AS STRING)        AS campaign_id,
        CAST(campaign_name AS STRING)      AS campaign_name,
        CAST(spend AS FLOAT64)             AS spend,
        CAST(impressions AS INT64)         AS impressions,
        CAST(clicks AS INT64)              AS clicks,
        CAST(conversions AS FLOAT64)       AS conversions,
        CAST(conversion_value AS FLOAT64)  AS conversion_value
    FROM {{core.criteo.campaign_performance_daily}}
)

SELECT
    date_day,
    source,
    account_id,
    MAX(account_name)       AS account_name,
    currency,
    campaign_id,
    MAX(campaign_name)      AS campaign_name,
    SUM(spend)              AS spend,
    SUM(impressions)        AS impressions,
    SUM(clicks)             AS clicks,
    SUM(conversions)        AS conversions,
    SUM(conversion_value)   AS conversion_value,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))             AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))                   AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000       AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))              AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))         AS roas
-- Grouped again because a platform model can carry an extra breakdown below the
-- campaign (Apple Ads reports campaigns per country or region).
FROM campaigns
GROUP BY date_day, source, account_id, currency, campaign_id
