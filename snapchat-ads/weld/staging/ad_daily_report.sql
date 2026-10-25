-- staging.snapchat_ads.ad_daily_report
-- Thin wrapper over raw `ad_daily_report`, Snapchat's ad stats at DAY granularity.
-- Casts, converts micros, de-duplicates. No other logic.
--
-- Grain: ad account x ad x reporting day.
--
-- MONEY IS IN MICROS. Snapchat returns spend and purchase value in millionths of
-- the ad account's currency; both are divided by 1,000,000 here.
--
-- report_start_at is the instant the account's reporting day starts, stored as a
-- UTC timestamp. For an account east of UTC that instant falls on the previous
-- UTC date, so DATE(report_start_at) is wrong there. Core converts it with the
-- account's own timezone.
--
-- Conversions use Snapchat's default attribution, because the connector does not
-- set it on the request: 28 days after a swipe up, 1 day after a view, counted
-- together. conversion_signups is not requested by the connector and stays NULL.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(ad_account_id AS STRING)                              AS account_id,
        CAST(ad_id AS STRING)                                      AS ad_id,
        CAST(date AS TIMESTAMP)                                    AS report_start_at,
        COALESCE(CAST(spend AS NUMERIC), 0) / 1000000              AS spend,
        COALESCE(CAST(impressions AS INT64), 0)                    AS impressions,
        COALESCE(CAST(swipes AS INT64), 0)                         AS swipes,
        COALESCE(CAST(video_views AS INT64), 0)                    AS video_views,
        COALESCE(CAST(view_completion AS INT64), 0)                AS video_completions,
        COALESCE(CAST(total_installs AS INT64), 0)                 AS app_installs,
        COALESCE(CAST(conversion_page_views AS INT64), 0)          AS page_view_conversions,
        COALESCE(CAST(conversion_add_cart AS INT64), 0)            AS add_to_cart_conversions,
        COALESCE(CAST(conversion_start_checkout AS INT64), 0)      AS start_checkout_conversions,
        COALESCE(CAST(conversion_purchases AS INT64), 0)           AS purchase_conversions,
        COALESCE(CAST(conversion_purchases_value AS NUMERIC), 0) / 1000000 AS purchase_value,
        ROW_NUMBER() OVER (
            PARTITION BY ad_account_id, ad_id, date
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.snapchat_ads.ad_daily_report}}
)
WHERE row_rank = 1
