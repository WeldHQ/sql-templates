-- core.linkedin_pages.follower_demographics
-- Who follows each LinkedIn Page: the follower breakdowns from the Followers
-- section of Page analytics (seniority, job function, industry, country,
-- location, company size, employees), in one long table.
--
-- Grain: organization_id x facet x segment_id. A snapshot as of the last sync.
-- Depends on: staging.linkedin_pages.followers_by_*, .total_follower_count
--
-- LinkedIn returns at most the top 100 segments per facet and leaves members who
-- did not fill in a field out of that facet, so a facet's segments rarely add up
-- to the Page's follower total. share_of_facet divides by the facet's own sum;
-- share_of_followers divides by the Page's total, so the gap shows what is not
-- covered. The tables are replaced on every sync, so there is no history: to
-- track demographics over time, snapshot this model on a schedule.

WITH segments AS (
    SELECT * FROM {{staging.linkedin_pages.followers_by_seniority}}
    UNION ALL
    SELECT * FROM {{staging.linkedin_pages.followers_by_function}}
    UNION ALL
    SELECT * FROM {{staging.linkedin_pages.followers_by_industry}}
    UNION ALL
    SELECT * FROM {{staging.linkedin_pages.followers_by_country}}
    UNION ALL
    SELECT * FROM {{staging.linkedin_pages.followers_by_location}}
    UNION ALL
    SELECT * FROM {{staging.linkedin_pages.followers_by_company_size}}
    UNION ALL
    SELECT * FROM {{staging.linkedin_pages.followers_by_association_type}}
)

SELECT
    s.organization_id,
    t.organization_name,
    s.facet,
    s.segment_id,
    s.segment_name,
    s.followers,
    SAFE_DIVIDE(s.followers, SUM(s.followers) OVER (PARTITION BY s.organization_id, s.facet)) AS share_of_facet,
    SAFE_DIVIDE(s.followers, t.follower_count)                                                AS share_of_followers,
    RANK() OVER (PARTITION BY s.organization_id, s.facet ORDER BY s.followers DESC)           AS segment_rank
FROM segments s
-- One row per organization after staging, so this cannot fan out.
LEFT JOIN {{staging.linkedin_pages.total_follower_count}} t USING (organization_id)
