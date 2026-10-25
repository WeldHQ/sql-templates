-- staging.google_ads.campaign_stats
-- Thin wrapper over raw `campaign_stats`, the daily campaign report. Casts,
-- converts micros, drops retracted rows, de-duplicates.
--
-- Grain: date x campaign x device x ad network (the report's own key).
-- Money is in micros in the raw table; spend here is in account currency.
-- See staging.google_ads.ad_stats for how retracted rows are handled.

SELECT * EXCEPT (row_rank, deleted_at)
FROM (
    SELECT
        CAST(date AS DATE)                          AS date_day,
        CAST(account_id AS STRING)                  AS account_id,
        CAST(account_descriptive_name AS STRING)    AS account_name,
        CAST(campaign_id AS STRING)                 AS campaign_id,
        CAST(campaign_name AS STRING)               AS campaign_name,
        CAST(device AS STRING)                      AS device,
        CAST(ad_network_type AS STRING)             AS ad_network_type,
        COALESCE(CAST(cost_micros AS INT64), 0) / 1000000 AS spend,
        COALESCE(CAST(impressions AS INT64), 0)     AS impressions,
        COALESCE(CAST(clicks AS INT64), 0)          AS clicks,
        COALESCE(CAST(interactions AS INT64), 0)    AS interactions,
        COALESCE(CAST(conversions AS FLOAT64), 0)   AS conversions,
        COALESCE(CAST(conversions_value AS FLOAT64), 0) AS conversion_value,
        COALESCE(CAST(view_through_conversions AS INT64), 0) AS view_through_conversions,
        COALESCE(CAST(video_views AS INT64), 0)     AS video_views,
        _weld_deleted_at                            AS deleted_at,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id, date, device, ad_network_type
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.google_ads.campaign_stats}}
)
WHERE row_rank = 1
  AND deleted_at IS NULL
