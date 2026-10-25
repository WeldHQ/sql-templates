-- staging.snapchat_ads.ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per ad account and ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(ad_account_id AS STRING)          AS account_id,
        CAST(id AS STRING)                     AS ad_id,
        CAST(name AS STRING)                   AS ad_name,
        CAST(ad_squad_id AS STRING)            AS ad_squad_id,
        CAST(creative_id AS STRING)            AS creative_id,
        CAST(type AS STRING)                   AS ad_type,
        CAST(status AS STRING)                 AS ad_status,
        CAST(review_status AS STRING)          AS review_status,
        COALESCE(CAST(deleted AS BOOL), FALSE) AS is_deleted,
        ROW_NUMBER() OVER (PARTITION BY ad_account_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.snapchat_ads.ad}}
)
WHERE row_rank = 1
