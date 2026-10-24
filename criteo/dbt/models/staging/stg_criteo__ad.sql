-- stg_criteo__ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                     AS ad_id,
        CAST(attributes_name AS STRING)        AS ad_name,
        CAST(attributes_ad_set_id AS STRING)   AS adset_id,
        CAST(attributes_creative_id AS STRING) AS creative_id,
        CAST(advertiser_id AS STRING)          AS account_id,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('criteo', 'ad') }}
)
WHERE row_rank = 1
