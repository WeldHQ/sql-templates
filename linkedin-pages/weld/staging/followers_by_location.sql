-- staging.linkedin_pages.followers_by_location
-- Thin wrapper over raw `follower_statistics_by_geo`: lifetime followers of
-- each LinkedIn Page by location (LinkedIn market area). Casts and renames into the shape that
-- core.linkedin_pages.follower_demographics unions. No other logic.
--
-- Grain: organization x location (LinkedIn market area). A snapshot as of the last sync; the
-- connector replaces the table every time. LinkedIn returns at most the top 100
-- segments and puts the whole count, organic and paid, in organic_follower_count.

SELECT
    CAST(organization_id AS STRING)                    AS organization_id,
    'location'                                         AS facet,
    CAST(geography_id AS STRING)                       AS segment_id,
    CAST(geography_name AS STRING)                     AS segment_name,
    CAST(COALESCE(organic_follower_count, 0) AS INT64) AS followers
FROM {{raw.linkedin_pages.follower_statistics_by_geo}}
