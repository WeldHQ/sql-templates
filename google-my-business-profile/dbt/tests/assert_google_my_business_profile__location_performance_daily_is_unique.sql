-- One row per day and location. A duplicate means the location join fanned out.

SELECT date_day, location_id, COUNT(*) AS row_count
FROM {{ ref('core_google_my_business_profile__location_performance_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
