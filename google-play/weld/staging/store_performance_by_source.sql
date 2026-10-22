-- staging.google_play.store_performance_by_source
-- Thin wrapper over raw `stats_store_performance_traffic_source`: store listing
-- visitors and acquisitions by traffic source, search term and UTM tags. Casts,
-- renames, keeps the latest version of each row.
--
-- Grain: one row per day x package x traffic source x search term x UTM source x
-- UTM campaign.
--
-- Visitors and acquisitions only count people who did not already have the app on
-- any of their devices, per Google's definition.

SELECT
    CAST(date AS DATE)                          AS date_day,
    CAST(package_name AS STRING)                AS package_name,
    CAST(traffic_source AS STRING)              AS traffic_source,
    CAST(search_term AS STRING)                 AS search_term,
    CAST(utm_source AS STRING)                  AS utm_source,
    CAST(utm_campaign AS STRING)                AS utm_campaign,
    CAST(store_listing_visitors AS INT64)       AS store_listing_visitors,
    CAST(store_listing_acquisitions AS INT64)   AS store_listing_acquisitions
FROM {{raw.google_play.stats_store_performance_traffic_source}}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, package_name, traffic_source, search_term, utm_source, utm_campaign
    ORDER BY file_last_modified DESC, _weld_synced DESC
) = 1
