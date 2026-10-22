-- staging.wordpress.posts
-- Thin wrapper over raw `wp_posts`, the table WordPress keeps every post, page,
-- revision, attachment and menu item in. Casts, renames, counts words, keeps the
-- latest row per ID. No filtering: core decides which post types count.
--
-- Grain: one row per wp_posts row (ID).
--
-- `wp_` is WordPress's default table prefix. If your site uses another one, change
-- the raw ref below and in staging.wordpress.postmeta.
--
-- Dates. post_date is in the site's own time zone, which is what wp-admin shows;
-- post_date_gmt is UTC and is empty on drafts that were never scheduled. Reports
-- use post_date so they match wp-admin.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(ID AS INT64)                           AS post_id,
        CAST(post_author AS INT64)                  AS author_id,
        CAST(post_type AS STRING)                   AS post_type,
        CAST(post_status AS STRING)                 AS post_status,
        CAST(post_title AS STRING)                  AS title,
        CAST(post_name AS STRING)                   AS slug,
        CAST(post_parent AS INT64)                  AS parent_id,
        CAST(guid AS STRING)                        AS guid,
        CAST(post_mime_type AS STRING)              AS mime_type,
        CAST(post_date AS TIMESTAMP)                AS published_at_local,
        DATE(CAST(post_date AS TIMESTAMP))          AS published_date,
        CAST(post_date_gmt AS TIMESTAMP)            AS published_at_utc,
        CAST(post_modified AS TIMESTAMP)            AS modified_at_local,
        DATE(CAST(post_modified AS TIMESTAMP))      AS modified_date,
        CAST(comment_count AS INT64)                AS comment_count,
        CAST(comment_status AS STRING)              AS comment_status,
        NULLIF(CAST(post_password AS STRING), '') IS NOT NULL AS is_password_protected,
        -- Words in the body with HTML tags and block comments stripped. An
        -- approximation of what an editor sees; shortcodes are counted as words.
        ARRAY_LENGTH(REGEXP_EXTRACT_ALL(
            REGEXP_REPLACE(COALESCE(CAST(post_content AS STRING), ''), r'<[^>]*>', ' '),
            r"[\p{L}\p{N}][\p{L}\p{N}'’-]*"
        ))                                          AS word_count,
        ROW_NUMBER() OVER (PARTITION BY ID ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.wordpress.wp_posts}}
)
WHERE row_rank = 1
