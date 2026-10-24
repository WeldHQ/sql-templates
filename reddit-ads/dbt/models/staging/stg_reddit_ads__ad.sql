-- stg_reddit_ads__ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)              AS ad_id,
        CAST(name AS STRING)            AS ad_name,
        CAST(ad_group_id AS STRING)     AS ad_group_id,
        CAST(campaign_id AS STRING)     AS campaign_id,
        CAST(ad_account_id AS STRING)   AS account_id,
        CAST(type AS STRING)            AS ad_type,
        CAST(effective_status AS STRING) AS effective_status,
        CAST(click_url AS STRING)       AS click_url,
        CAST(post_url AS STRING)        AS post_url,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('reddit_ads', 'ad') }}
)
WHERE row_rank = 1
