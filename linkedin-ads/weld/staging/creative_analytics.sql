-- staging.linkedin_ads.creative_analytics
-- Thin wrapper over raw `ad_analytics_by_creative`, LinkedIn's daily ad analytics
-- pivoted by creative. Casts, renames, de-duplicates. No other logic.
--
-- Grain: creative_id x date_day.
--
-- The table carries no account id: the connector requests it once per ad account
-- and keeps only the creative id. Core takes the account from the creative.
--
-- Money: `cost_in_local_currency` and `conversion_value_in_local_currency` are in
-- the ad account's currency and become `spend` and `conversion_value`.
-- `cost_in_usd` is kept as `spend_usd` for cross-currency totals. No micros here.
--
-- Days are UTC days, which is how LinkedIn's analytics API buckets daily data.

SELECT
    CAST(creative_id AS STRING)                                         AS creative_id,
    SAFE_CAST(LEFT(CAST(date AS STRING), 10) AS DATE)                   AS date_day,
    COALESCE(CAST(impressions AS INT64), 0)                             AS impressions,
    COALESCE(CAST(clicks AS INT64), 0)                                  AS clicks,
    COALESCE(CAST(landing_page_clicks AS INT64), 0)                     AS landing_page_clicks,
    COALESCE(CAST(cost_in_local_currency AS FLOAT64), 0)                AS spend,
    COALESCE(CAST(cost_in_usd AS FLOAT64), 0)                           AS spend_usd,
    COALESCE(CAST(external_website_conversions AS FLOAT64), 0)          AS website_conversions,
    COALESCE(CAST(external_website_post_click_conversions AS FLOAT64), 0) AS website_post_click_conversions,
    COALESCE(CAST(external_website_post_view_conversions AS FLOAT64), 0)  AS website_post_view_conversions,
    CAST(conversion_value_in_local_currency AS FLOAT64)                 AS conversion_value,
    COALESCE(CAST(one_click_leads AS FLOAT64), 0)                       AS leads,
    COALESCE(CAST(one_click_lead_form_opens AS INT64), 0)               AS lead_form_opens,
    COALESCE(CAST(total_engagements AS INT64), 0)                       AS engagements,
    COALESCE(CAST(video_views AS INT64), 0)                             AS video_views
FROM {{raw.linkedin_ads.ad_analytics_by_creative}}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY creative_id, date ORDER BY _weld_synced DESC) = 1
