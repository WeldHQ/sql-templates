-- Logins per application and connection add up to the tenant total for each day.
-- Both are counted from the same log, so any difference means a filter or join in
-- logins_by_application is dropping or duplicating events.

WITH by_app AS (
    SELECT date_day, SUM(logins) AS logins, SUM(failed_logins) AS failed_logins
    FROM {{ ref('core_auth0__logins_by_application') }}
    GROUP BY 1
)

SELECT
    t.date_day,
    t.log_logins,
    a.logins,
    t.log_failed_logins,
    a.failed_logins
FROM {{ ref('core_auth0__tenant_activity_daily') }} t
JOIN by_app a
  ON a.date_day = t.date_day
WHERE t.log_logins != a.logins
   OR t.log_failed_logins != a.failed_logins
