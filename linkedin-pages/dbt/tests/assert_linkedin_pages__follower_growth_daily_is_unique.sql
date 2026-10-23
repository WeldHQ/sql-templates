-- One row per day and organization. A duplicate means the follower total join
-- fanned out, which would also break the running estimate.

SELECT date_day, organization_id, COUNT(*) AS row_count
FROM {{ ref('core_linkedin_pages__follower_growth_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
