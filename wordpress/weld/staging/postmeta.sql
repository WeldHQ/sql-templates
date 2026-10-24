-- staging.wordpress.postmeta
-- Thin wrapper over raw `wp_postmeta`: WordPress's key-value store of extra fields
-- per post (featured image, page template, plugin data). Casts, renames,
-- de-duplicates.
--
-- Grain: one row per meta_id. A post can have the same meta_key more than once.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(meta_id AS INT64)      AS meta_id,
        CAST(post_id AS INT64)      AS post_id,
        CAST(meta_key AS STRING)    AS meta_key,
        CAST(meta_value AS STRING)  AS meta_value,
        ROW_NUMBER() OVER (PARTITION BY meta_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.wordpress.wp_postmeta}}
)
WHERE row_rank = 1
