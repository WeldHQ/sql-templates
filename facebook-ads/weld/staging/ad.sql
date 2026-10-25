-- staging.facebook_ads.ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                                       AS ad_id,
        CAST(adset_id AS STRING)                                 AS ad_set_id,
        CAST(campaign_id AS STRING)                              AS campaign_id,
        REGEXP_REPLACE(CAST(account_id AS STRING), r'^act_', '') AS account_id,
        CAST(creative_id AS STRING)                              AS creative_id,
        CAST(name AS STRING)                                     AS ad_name,
        CAST(effective_status AS STRING)                         AS effective_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.facebook_ads.ad}}
)
WHERE row_rank = 1
