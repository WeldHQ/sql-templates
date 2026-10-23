-- One row per day and account. A duplicate means the profile join fanned out or
-- the staging dedupe on date missed a repeated day.

SELECT date_day, business_id, COUNT(*) AS row_count
FROM {{ ref('core_tiktok_organic__profile_performance_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
