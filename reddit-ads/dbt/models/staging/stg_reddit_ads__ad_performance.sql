-- stg_reddit_ads__ad_performance
-- Thin wrapper over a Reddit Ads custom report named "ad_performance". Casts,
-- converts micros, de-duplicates. No other logic.
--
-- Grain: ad account x report window x ad x date.
--
-- REQUIRED REPORT SETUP. Reddit Ads reports are custom reports in Weld: you pick
-- the breakdowns and fields, and the stream is named after the report. This model
-- expects a report named "ad_performance" with
--   breakdowns: AD_ID, DATE
--   fields:     IMPRESSIONS, CLICKS, SPEND, CONVERSION_PURCHASE_CLICKS,
--               CONVERSION_PURCHASE_VIEWS, CONVERSION_PURCHASE_TOTAL_VALUE
-- and the timezone set to the ad account's own timezone, so dates line up with
-- Ads Manager. Every report column lands as a string, hence the casts.
--
-- MONEY IS IN MICROS. Reddit returns spend in millionths of the account currency.
-- Purchase value is an integer field too and is converted the same way; check one
-- day against Ads Manager before relying on it.
--
-- Weld requests one UTC day per call. With a non-UTC report timezone one window
-- can return two local dates, and one local date arrives from two windows, so
-- core SUMs across windows rather than picking one.

SELECT
    account_id,
    window_starts_at,
    ad_id,
    date_day,
    impressions,
    clicks,
    spend,
    purchase_click_conversions,
    purchase_view_conversions,
    purchase_value
FROM (
    SELECT
        CAST(account_id AS STRING)                                  AS account_id,
        CAST(starts_at AS TIMESTAMP)                                AS window_starts_at,
        CAST(ad_id AS STRING)                                       AS ad_id,
        COALESCE(SAFE_CAST(LEFT(CAST(date AS STRING), 10) AS DATE),
                 DATE(CAST(starts_at AS TIMESTAMP)))                AS date_day,
        COALESCE(SAFE_CAST(impressions AS INT64), 0)                AS impressions,
        COALESCE(SAFE_CAST(clicks AS INT64), 0)                     AS clicks,
        COALESCE(SAFE_CAST(spend AS NUMERIC), 0) / 1000000          AS spend,
        COALESCE(SAFE_CAST(conversion_purchase_clicks AS NUMERIC), 0) AS purchase_click_conversions,
        COALESCE(SAFE_CAST(conversion_purchase_views AS NUMERIC), 0)  AS purchase_view_conversions,
        COALESCE(SAFE_CAST(conversion_purchase_total_value AS NUMERIC), 0) / 1000000 AS purchase_value,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, starts_at, ends_at, ad_id, date
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('reddit_ads', 'ad_performance') }}
)
WHERE row_rank = 1
