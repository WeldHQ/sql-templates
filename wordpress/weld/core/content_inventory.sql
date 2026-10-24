-- core.wordpress.content_inventory
-- Every published post and page with its length, age, last update, comments and
-- featured image: the Posts and Pages lists in wp-admin, as a content audit.
--
-- Grain: one row per published post or page (current state as of the last sync).
-- Depends on: staging.wordpress.posts, staging.wordpress.postmeta
--
-- Only post_type 'post' and 'page' with status 'publish' are included. Custom post
-- types (products, events, case studies) are left out because their names differ
-- per site: add them to the IN list below. Revisions, attachments, menu items and
-- auto-drafts are WordPress internals and never belong here.
--
-- `revisions` counts saved revisions of the post, which is how often it has been
-- edited since revisions were enabled. Sites that disable or prune revisions will
-- show zero.

WITH featured AS (
    SELECT DISTINCT post_id
    FROM {{staging.wordpress.postmeta}}
    WHERE meta_key = '_thumbnail_id'
      AND NULLIF(meta_value, '') IS NOT NULL
      AND meta_value != '0'
),

revisions AS (
    SELECT
        parent_id                   AS post_id,
        COUNT(*)                    AS revisions,
        MAX(published_at_local)     AS last_revision_at_local
    FROM {{staging.wordpress.posts}}
    WHERE post_type = 'revision'
    GROUP BY parent_id
)

SELECT
    p.post_id,
    p.post_type,
    p.title,
    p.slug,
    p.author_id,
    p.published_at_local,
    p.published_date,
    p.modified_at_local,
    p.modified_date,
    DATE_DIFF(CURRENT_DATE(), p.published_date, DAY)        AS days_since_published,
    DATE_DIFF(CURRENT_DATE(), p.modified_date, DAY)         AS days_since_modified,
    p.word_count,
    p.comment_count,
    p.is_password_protected,
    f.post_id IS NOT NULL                                   AS has_featured_image,
    COALESCE(r.revisions, 0)                                AS revisions,
    r.last_revision_at_local,

    -- Not touched in a year: the usual starting list for a content refresh. One
    -- threshold, here; change it to your editorial policy.
    DATE_DIFF(CURRENT_DATE(), p.modified_date, DAY) > 365   AS is_stale,
    p.word_count < 300                                      AS is_thin
FROM {{staging.wordpress.posts}} p
LEFT JOIN featured f
  ON f.post_id = p.post_id
LEFT JOIN revisions r
  ON r.post_id = p.post_id
WHERE p.post_type IN ('post', 'page')
  AND p.post_status = 'publish'
