-- core_google_play__store_listing_conversion
-- Store listing visitors, acquisitions and conversion rate by traffic source: the
-- Store performance report in Play Console.
--
-- Grain: one row per day x package x traffic source.
-- Depends on: staging.google_play.store_performance_by_source
--
-- Google ships a conversion rate per row; it is not reused here, because a rate
-- cannot be summed. conversion_rate is recomputed from summed acquisitions and
-- visitors, so it stays right when rolled up to a week or across sources. Search
-- terms and UTM tags are summed away in this model; they are in the staging model
-- if you need them.

SELECT
    date_day,
    package_name,
    traffic_source,
    SUM(store_listing_visitors)                                         AS store_listing_visitors,
    SUM(store_listing_acquisitions)                                     AS store_listing_acquisitions,
    ROUND(SAFE_DIVIDE(SUM(store_listing_acquisitions),
                      NULLIF(SUM(store_listing_visitors), 0)), 4)       AS conversion_rate
FROM {{ ref('stg_google_play__store_performance_by_source') }}
GROUP BY date_day, package_name, traffic_source
