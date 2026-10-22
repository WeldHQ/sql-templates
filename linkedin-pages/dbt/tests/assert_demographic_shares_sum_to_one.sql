-- Within an organization and facet, the segment shares must add up to 1.

SELECT organization_id, facet, SUM(share_of_facet) AS share_total
FROM {{ ref('core_linkedin_pages__follower_demographics') }}
GROUP BY 1, 2
HAVING SUM(followers) > 0 AND ABS(SUM(share_of_facet) - 1) > 0.0001
