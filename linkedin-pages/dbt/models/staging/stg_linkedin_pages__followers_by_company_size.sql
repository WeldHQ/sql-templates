-- stg_linkedin_pages__followers_by_company_size
-- Thin wrapper over raw `follower_statistics_by_staff_count_range`: lifetime followers of
-- each LinkedIn Page by company size. Casts and renames into the shape that
-- core.linkedin_pages.follower_demographics unions. No other logic.
--
-- Grain: organization x company size. A snapshot as of the last sync; the
-- connector replaces the table every time. LinkedIn returns at most the top 100
-- segments and puts the whole count, organic and paid, in organic_follower_count.
-- segment_name is LinkedIn's size code, such as SIZE_11_TO_50, for the
-- follower's own employer.

SELECT
    CAST(organization_id AS STRING)                    AS organization_id,
    'company_size'                                     AS facet,
    CAST(staff_count_id AS STRING)                     AS segment_id,
    CAST(staff_count_range AS STRING)                  AS segment_name,
    CAST(COALESCE(organic_follower_count, 0) AS INT64) AS followers
FROM {{ source('linkedin_pages', 'follower_statistics_by_staff_count_range') }}
