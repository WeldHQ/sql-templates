-- stg_facebook_pages__post
-- Thin wrapper over raw `post`. Casts, renames, keeps the latest row per post. No
-- other logic.
--
-- Grain: one row per post. When the connector syncs more than one Page, this
-- table is named `<page_name>__<page_id>__post`, one per Page: UNION ALL them here.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                 AS post_id,
        CAST(page_id AS STRING)            AS page_id,
        CAST(created_time AS TIMESTAMP)    AS created_at,
        CAST(message AS STRING)            AS message,
        CAST(status_type AS STRING)        AS status_type,
        CAST(permalink_url AS STRING)      AS permalink_url,
        CAST(is_published AS BOOL)         AS is_published,
        CAST(shares_count AS INT64)        AS shares_count,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('facebook_pages', 'post') }}
)
WHERE row_rank = 1
