-- stg_tiktok_ads__ad_daily_report
-- Thin wrapper over raw `ad_daily_report`, TikTok's basic auction report at ad
-- level by day. Casts, renames, de-duplicates. No other logic.
--
-- Grain: advertiser x ad x day, the stream's own key (advertiser_id, ad_id,
-- stat_time_day).
--
-- TikTok's reporting API returns every metric as a string. The connector converts
-- them to numbers on load, so the casts here are a safety net. stat_time_day stays
-- a string ("2024-05-01 00:00:00") and is cut to a DATE. Days are in the
-- advertiser's timezone, the same days Ads Manager shows.
--
-- Money is in the advertiser's currency, in whole units (no micros).
--
-- conversion counts the optimisation event of the ad's ad group (see
-- staging.tiktok_ads.ad_group.optimization_goal), under the attribution window
-- set on that ad group. complete_payment is the website Complete Payment event.
-- The connector syncs its count and its average value, not its total value, so
-- complete_payment_value is rebuilt as count x average value; TikTok rounds the
-- average, so expect differences of a few cents per row.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)                                  AS account_id,
        CAST(ad_id AS STRING)                                          AS ad_id,
        SAFE_CAST(LEFT(CAST(stat_time_day AS STRING), 10) AS DATE)     AS date_day,
        COALESCE(SAFE_CAST(spend AS FLOAT64), 0)                       AS spend,
        COALESCE(SAFE_CAST(impressions AS INT64), 0)                   AS impressions,
        COALESCE(SAFE_CAST(clicks AS INT64), 0)                        AS clicks,
        COALESCE(SAFE_CAST(reach AS INT64), 0)                         AS reach,
        COALESCE(SAFE_CAST(conversion AS INT64), 0)                    AS conversions,
        COALESCE(SAFE_CAST(result AS INT64), 0)                        AS results,
        COALESCE(SAFE_CAST(complete_payment AS INT64), 0)              AS complete_payments,
        COALESCE(SAFE_CAST(complete_payment AS INT64), 0)
            * COALESCE(SAFE_CAST(value_per_complete_payment AS FLOAT64), 0) AS complete_payment_value,
        COALESCE(SAFE_CAST(total_purchase AS INT64), 0)                AS app_purchases,
        COALESCE(SAFE_CAST(total_purchase_value AS FLOAT64), 0)        AS app_purchase_value,
        COALESCE(SAFE_CAST(video_play_actions AS INT64), 0)            AS video_views,
        COALESCE(SAFE_CAST(video_watched_6s AS INT64), 0)              AS video_views_6s,
        COALESCE(SAFE_CAST(video_views_p100 AS INT64), 0)              AS video_completions,
        COALESCE(SAFE_CAST(likes AS INT64), 0)                         AS likes,
        COALESCE(SAFE_CAST(comments AS INT64), 0)                      AS comments,
        COALESCE(SAFE_CAST(shares AS INT64), 0)                        AS shares,
        COALESCE(SAFE_CAST(follows AS INT64), 0)                       AS follows,
        ROW_NUMBER() OVER (
            PARTITION BY advertiser_id, ad_id, stat_time_day
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('tiktok_ads', 'ad_daily_report') }}
)
WHERE row_rank = 1
