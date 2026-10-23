-- One row per day and Page. A duplicate means the Page join fanned out or the
-- staging dedupe on end_time missed a repeated day.

SELECT date_day, page_id, COUNT(*) AS row_count
FROM {{ ref('core_facebook_pages__page_performance_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
