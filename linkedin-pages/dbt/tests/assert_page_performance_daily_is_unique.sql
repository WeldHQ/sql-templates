-- One row per day and organization. A duplicate means the staging dedupe on
-- start_date missed a repeated day.

SELECT date_day, organization_id, COUNT(*) AS row_count
FROM {{ ref('core_linkedin_pages__page_performance_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
