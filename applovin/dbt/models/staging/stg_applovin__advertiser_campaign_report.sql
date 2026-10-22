-- stg_applovin__advertiser_campaign_report
-- Thin wrapper over raw `advertiser_campaign_report`, the AppLovin advertiser
-- report at campaign level. Casts, renames, de-duplicates. No other logic.
--
-- Grain: day x campaign x creative set x country x platform x device type x
-- placement type x ad size x traffic source x custom product page x campaign type,
-- the key the connector writes with.
--
-- Days are UTC, as the AppLovin reporting API returns them. Delivery metrics are
-- dated on the day they happened. The _0d, _1d and _7d columns are install-cohort
-- metrics: revenue from users who installed on that day, within N days. The
-- connector only requests a window once it has fully elapsed, so _7d is NULL for
-- the last seven days. The connector re-reads the last seven days once a day,
-- and the latest synced row per key wins.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        day                                        AS date_day,
        CAST(campaign_id_external AS STRING)       AS campaign_id,
        CAST(campaign AS STRING)                   AS campaign_name,
        CAST(campaign_type AS STRING)              AS campaign_type,
        CAST(campaign_bid_goal AS STRING)          AS campaign_bid_goal,
        CAST(campaign_package_name AS STRING)      AS app_package_name,
        CAST(campaign_store_id AS STRING)          AS app_store_id,
        CAST(creative_set AS STRING)               AS creative_set_name,
        CAST(country AS STRING)                    AS country,
        CAST(platform AS STRING)                   AS platform,
        CAST(device_type AS STRING)                AS device_type,
        CAST(placement_type AS STRING)             AS placement_type,
        CAST(size AS STRING)                       AS ad_size,
        CAST(traffic_source AS STRING)             AS traffic_source,
        CAST(custom_page_id AS STRING)             AS custom_page_id,
        CAST(COALESCE(cost, 0) AS NUMERIC)         AS spend,
        CAST(COALESCE(impressions, 0) AS INT64)    AS impressions,
        CAST(COALESCE(clicks, 0) AS INT64)         AS clicks,
        CAST(COALESCE(conversions, 0) AS NUMERIC)  AS installs,
        CAST(COALESCE(sales, 0) AS NUMERIC)        AS sales,
        CAST(total_rev_0d AS NUMERIC)              AS total_revenue_d0,
        CAST(total_rev_7d AS NUMERIC)              AS total_revenue_d7,
        CAST(iap_rev_7d AS NUMERIC)                AS iap_revenue_d7,
        CAST(ad_rev_7d AS NUMERIC)                 AS ad_revenue_d7,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id_external, creative_set, campaign_type, country,
                         custom_page_id, day, device_type, placement_type, platform,
                         size, traffic_source
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('applovin', 'advertiser_campaign_report') }}
)
WHERE row_rank = 1
