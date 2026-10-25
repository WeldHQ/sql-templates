-- staging.pinterest_ads.ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per ad. A Pinterest ad is a promoted Pin.

SELECT
    CAST(id AS STRING)               AS ad_id,
    CAST(ad_account_id AS STRING)    AS account_id,
    CAST(campaign_id AS STRING)      AS campaign_id,
    CAST(ad_group_id AS STRING)      AS ad_group_id,
    CAST(pin_id AS STRING)           AS pin_id,
    CAST(name AS STRING)             AS ad_name,
    CAST(status AS STRING)           AS ad_status,
    CAST(creative_type AS STRING)    AS creative_type,
    CAST(destination_url AS STRING)  AS destination_url,
    CAST(created_time AS TIMESTAMP)  AS created_time
FROM {{raw.pinterest_ads.ad}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY ad_account_id, id ORDER BY _weld_synced DESC) = 1
