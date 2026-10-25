-- staging.google_ads.ad_group_country_stats
-- Thin wrapper over raw `ad_group_country_stats`, Google's geographic report
-- (user locations) by ad group and country. Casts, converts micros, drops
-- retracted rows, de-duplicates.
--
-- Grain: date x ad group x device x ad network x country x location type
-- (the report's own key). country_criterion_id is a Google geo target ID;
-- staging.google_ads.geo_target names it.

SELECT * EXCEPT (row_rank, deleted_at)
FROM (
    SELECT
        CAST(date AS DATE)                          AS date_day,
        CAST(account_id AS STRING)                  AS account_id,
        CAST(campaign_id AS STRING)                 AS campaign_id,
        CAST(campaign_name AS STRING)               AS campaign_name,
        CAST(ad_group_id AS STRING)                 AS ad_group_id,
        CAST(country_criterion_id AS STRING)        AS country_criterion_id,
        CAST(location_type AS STRING)               AS location_type,
        CAST(device AS STRING)                      AS device,
        CAST(ad_network_type AS STRING)             AS ad_network_type,
        COALESCE(CAST(cost_micros AS INT64), 0) / 1000000 AS spend,
        COALESCE(CAST(impressions AS INT64), 0)     AS impressions,
        COALESCE(CAST(clicks AS INT64), 0)          AS clicks,
        COALESCE(CAST(conversions AS FLOAT64), 0)   AS conversions,
        COALESCE(CAST(conversions_value AS FLOAT64), 0) AS conversion_value,
        _weld_deleted_at                            AS deleted_at,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, campaign_id, ad_group_id, date, device, ad_network_type, country_criterion_id, location_type
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.google_ads.ad_group_country_stats}}
)
WHERE row_rank = 1
  AND deleted_at IS NULL
