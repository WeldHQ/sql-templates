-- One row per day in the global stats, and per day x category in the category stats.
--
-- SendGrid restates recent days as late opens and clicks arrive, and the stream can land
-- a date more than once. The staging models keep the latest copy; if that ever stops
-- working the totals inflate silently, so this checks the grain the core models state.

SELECT 'email_stats_daily' AS model, CAST(date AS STRING) AS key, COUNT(*) AS row_count
FROM {{ ref('core_sendgrid__email_stats_daily') }}
GROUP BY date
HAVING COUNT(*) > 1

UNION ALL

SELECT 'category_stats_daily', CONCAT(CAST(date AS STRING), ' / ', category), COUNT(*)
FROM {{ ref('core_sendgrid__category_stats_daily') }}
GROUP BY date, category
HAVING COUNT(*) > 1
