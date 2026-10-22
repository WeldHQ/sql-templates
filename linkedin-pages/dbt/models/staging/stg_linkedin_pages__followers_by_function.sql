-- stg_linkedin_pages__followers_by_function
-- Thin wrapper over raw `follower_statistics_by_function`: lifetime followers of
-- each LinkedIn Page by job function. Casts and renames into the shape that
-- core.linkedin_pages.follower_demographics unions. No other logic.
--
-- Grain: organization x job function. A snapshot as of the last sync; the
-- connector replaces the table every time. LinkedIn returns at most the top 100
-- segments and puts the whole count, organic and paid, in organic_follower_count.

SELECT
    CAST(organization_id AS STRING)                    AS organization_id,
    'function'                                         AS facet,
    CAST(function_id AS STRING)                        AS segment_id,
    CAST(function_name AS STRING)                      AS segment_name,
    CAST(COALESCE(organic_follower_count, 0) AS INT64) AS followers
FROM {{ source('linkedin_pages', 'follower_statistics_by_function') }}
