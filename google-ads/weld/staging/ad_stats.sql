-- staging.google_ads.ad_stats
-- Thin wrapper over raw `ad_stats`, the daily ad report. Casts, converts micros,
-- drops rows the connector has retracted, de-duplicates.
--
-- Grain: date x account x campaign x ad group x ad x device x ad network. Google
-- identifies an ad by its ad group and ad id together, so both are in the key.
--
-- MONEY IS IN MICROS. Google returns cost as millionths of the account currency;
-- spend here is divided by 1,000,000. conversions_value is already in currency.
--
-- Retracted rows: the connector re-reads the last 30 days once a day and marks
-- report rows that Google no longer returns (for example invalid clicks removed
-- after the fact) with _weld_deleted_at. Those rows are dropped here.

SELECT * EXCEPT (row_rank, deleted_at)
FROM (
    SELECT
        CAST(date AS DATE)                          AS date_day,
        CAST(account_id AS STRING)                  AS account_id,
        CAST(account_descriptive_name AS STRING)    AS account_name,
        CAST(campaign_id AS STRING)                 AS campaign_id,
        CAST(campaign_name AS STRING)               AS campaign_name,
        CAST(ad_group_id AS STRING)                 AS ad_group_id,
        CAST(ad_group_name AS STRING)               AS ad_group_name,
        CAST(ad_id AS STRING)                       AS ad_id,
        CAST(ad_name AS STRING)                     AS ad_name,
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
            PARTITION BY account_id, campaign_id, ad_group_id, ad_id, date, device, ad_network_type
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.google_ads.ad_stats}}
)
WHERE row_rank = 1
  AND deleted_at IS NULL
