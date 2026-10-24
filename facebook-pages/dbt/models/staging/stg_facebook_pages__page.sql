-- stg_facebook_pages__page
-- Thin wrapper over raw `page`. Casts, renames, keeps the latest row per Page. No
-- other logic.
--
-- Grain: one row per Page. followers_count and fan_count are the values at the
-- last sync, not a history.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                 AS page_id,
        CAST(name AS STRING)               AS page_name,
        CAST(username AS STRING)           AS username,
        CAST(category AS STRING)           AS category,
        CAST(link AS STRING)               AS page_url,
        CAST(followers_count AS INT64)     AS followers_count,
        CAST(fan_count AS INT64)           AS fan_count,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('facebook_pages', 'page') }}
)
WHERE row_rank = 1
