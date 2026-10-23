-- One row per day x event in events_daily, and one per day in active_users_daily.
--
-- The events stream appends, so raw can hold the same event twice. Staging keeps one row
-- per event under Mixpanel's duplicate rule. If that breaks, event totals inflate; this checks the grains the core
-- models state and that DAU never exceeds MAU.

SELECT 'events_daily' AS check_name, CONCAT(CAST(date AS STRING), ' / ', event_name) AS key
FROM {{ ref('core_mixpanel_source__events_daily') }}
GROUP BY date, event_name
HAVING COUNT(*) > 1

UNION ALL

SELECT 'active_users_daily_grain', CAST(date AS STRING)
FROM {{ ref('core_mixpanel_source__active_users_daily') }}
GROUP BY date
HAVING COUNT(*) > 1

UNION ALL

SELECT 'dau_above_wau_or_mau', CAST(date AS STRING)
FROM {{ ref('core_mixpanel_source__active_users_daily') }}
WHERE dau > wau OR wau > mau
