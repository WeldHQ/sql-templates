-- stg_facebook_pages__post_lifetime_insights
-- Thin wrapper over raw `post_lifetime_insights`, the post metrics with period
-- `lifetime`. Casts, renames, keeps the latest row per key. No other logic.
--
-- Grain: post x metric x breakdown (long format). Values are cumulative over the
-- post's life up to the last sync, which re-reads every post: never sum them
-- across syncs or days. Object metrics (actions by type) arrive as one row per
-- key in `breakdown`; plain metrics have breakdown NULL.
-- When the connector syncs more than one Page, this table is named
-- `<page_name>__<page_id>__post_lifetime_insights`: UNION ALL them here.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(post_id AS STRING)                                    AS post_id,
        CAST(name AS STRING)                                       AS metric,
        NULLIF(NULLIF(CAST(type AS STRING), 'none'), 'unknown')    AS breakdown,
        CAST(COALESCE(value, 0) AS FLOAT64)                        AS value,
        CAST(_weld_synced AS TIMESTAMP)                            AS synced_at,
        ROW_NUMBER() OVER (
            PARTITION BY post_id, name, type ORDER BY _weld_synced DESC
        )                                                          AS row_rank
    FROM {{ source('facebook_pages', 'post_lifetime_insights') }}
    WHERE period = 'lifetime'
)
WHERE row_rank = 1
