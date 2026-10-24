-- stg_tiktok_organic__profile
-- Thin wrapper over raw `profile`, the connected TikTok business account. Casts,
-- renames, keeps the latest row per account. No other logic.
--
-- Grain: one row per account. followers_count is the value at the last sync.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(business_id AS STRING)           AS business_id,
        CAST(username AS STRING)              AS username,
        CAST(display_name AS STRING)          AS display_name,
        CAST(is_business_account AS BOOL)     AS is_business_account,
        CAST(followers_count AS INT64)        AS followers_count,
        ROW_NUMBER() OVER (PARTITION BY business_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('tiktok_organic', 'profile') }}
)
WHERE row_rank = 1
