-- stg_linkedin_pages__followers_by_association_type
-- Thin wrapper over raw `follower_statistics_by_association_type`: lifetime followers of
-- each LinkedIn Page by association type. Casts and renames into the shape that
-- core.linkedin_pages.follower_demographics unions. No other logic.
--
-- Grain: organization x association type. A snapshot as of the last sync; the
-- connector replaces the table every time. LinkedIn returns at most the top 100
-- segments and puts the whole count, organic and paid, in organic_follower_count.
-- The only association type LinkedIn reports is EMPLOYEE: followers who list
-- the organization as their employer.

SELECT
    CAST(organization_id AS STRING)                    AS organization_id,
    'association_type'                                 AS facet,
    CAST(association_type_id AS STRING)                AS segment_id,
    CAST(association_type AS STRING)                   AS segment_name,
    CAST(COALESCE(organic_follower_count, 0) AS INT64) AS followers
FROM {{ source('linkedin_pages', 'follower_statistics_by_association_type') }}
