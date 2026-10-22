-- stg_applovin__advertiser_report
-- Thin wrapper over raw `advertiser_report`, the AppLovin advertiser report with
-- creative set and ad columns. Casts, renames, de-duplicates. No other logic.
--
-- Grain: the campaign report's key (see staging.applovin.advertiser_campaign_report)
-- plus ad type, creative set id and external placement, the key the connector
-- writes with. The ad name is not part of that key.
--
-- Days are UTC. Cohort columns (_0d, _7d) follow the same rules as in the
-- campaign report: _7d is NULL for the last seven days.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        day                                        AS date_day,
        CAST(campaign_id_external AS STRING)       AS campaign_id,
        CAST(campaign AS STRING)                   AS campaign_name,
        CAST(campaign_type AS STRING)              AS campaign_type,
        CAST(campaign_package_name AS STRING)      AS app_package_name,
        CAST(creative_set_id AS STRING)            AS creative_set_id,
        CAST(creative_set AS STRING)               AS creative_set_name,
        CAST(ad AS STRING)                         AS ad_name,
        CAST(ad_type AS STRING)                    AS ad_type,
        CAST(ad_creative_type AS STRING)           AS ad_creative_type,
        CAST(external_placement_id AS STRING)      AS external_placement_id,
        CAST(country AS STRING)                    AS country,
        CAST(platform AS STRING)                   AS platform,
        CAST(traffic_source AS STRING)             AS traffic_source,
        CAST(COALESCE(cost, 0) AS NUMERIC)         AS spend,
        CAST(COALESCE(impressions, 0) AS INT64)    AS impressions,
        CAST(COALESCE(clicks, 0) AS INT64)         AS clicks,
        CAST(COALESCE(conversions, 0) AS NUMERIC)  AS installs,
        CAST(COALESCE(sales, 0) AS NUMERIC)        AS sales,
        CAST(total_rev_0d AS NUMERIC)              AS total_revenue_d0,
        CAST(total_rev_7d AS NUMERIC)              AS total_revenue_d7,
        ROW_NUMBER() OVER (
            PARTITION BY ad_type, creative_set_id, external_placement_id,
                         campaign_id_external, creative_set, campaign_type, country,
                         custom_page_id, day, device_type, placement_type, platform,
                         size, traffic_source
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('applovin', 'advertiser_report') }}
)
WHERE row_rank = 1
