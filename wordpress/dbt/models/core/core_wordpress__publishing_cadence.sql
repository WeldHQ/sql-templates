-- core_wordpress__publishing_cadence
-- How much is published and edited each month, per author and content type: the
-- editorial output report WordPress itself does not have.
--
-- Grain: one row per month (site time zone) x post type x author.
-- Depends on: staging.wordpress.posts
--
-- `posts_published` counts content that is published now, on the month of its
-- publish date. A post unpublished later drops out of its month, so past months can
-- shrink slightly; WordPress keeps no publish history to avoid that.
--
-- `edits` counts saved revisions in the month, attributed to the revision's author
-- (the person who saved it), not to the post's author. Autosaves are revisions too
-- in WordPress and are included.

WITH published AS (
    SELECT
        DATE_TRUNC(published_date, MONTH)   AS month_start,
        post_type,
        author_id,
        COUNT(*)                            AS posts_published,
        SUM(word_count)                     AS words_published
    FROM {{ ref('stg_wordpress__posts') }}
    WHERE post_type IN ('post', 'page')
      AND post_status = 'publish'
    GROUP BY 1, 2, 3
),

edits AS (
    SELECT
        DATE_TRUNC(r.published_date, MONTH) AS month_start,
        p.post_type,
        r.author_id,
        COUNT(*)                            AS edits,
        COUNT(DISTINCT r.parent_id)         AS posts_edited
    FROM {{ ref('stg_wordpress__posts') }} r
    JOIN {{ ref('stg_wordpress__posts') }} p
      ON p.post_id = r.parent_id
    WHERE r.post_type = 'revision'
      AND p.post_type IN ('post', 'page')
      AND p.post_status = 'publish'
    GROUP BY 1, 2, 3
)

SELECT
    COALESCE(pub.month_start, e.month_start)    AS month_start,
    COALESCE(pub.post_type, e.post_type)        AS post_type,
    COALESCE(pub.author_id, e.author_id)        AS author_id,
    COALESCE(pub.posts_published, 0)            AS posts_published,
    COALESCE(pub.words_published, 0)            AS words_published,
    ROUND(SAFE_DIVIDE(pub.words_published, NULLIF(pub.posts_published, 0)), 0) AS avg_words_per_post,
    COALESCE(e.edits, 0)                        AS edits,
    COALESCE(e.posts_edited, 0)                 AS posts_edited
FROM published pub
FULL OUTER JOIN edits e
  ON  e.month_start = pub.month_start
  AND e.post_type   = pub.post_type
  AND e.author_id   = pub.author_id
