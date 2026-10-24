-- One row per day and site. A duplicate means the query join fanned out.

SELECT date_day, site, COUNT(*) AS row_count
FROM {{ ref('core_google_search_console__site_performance_daily') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
