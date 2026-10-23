-- One row per day in tenant_activity_daily.
-- The model full-outer-joins Auth0's own counters to the log; a duplicate day means
-- one side stopped being unique, and every daily chart would double that day.

SELECT
    date_day,
    COUNT(*) AS row_count
FROM {{ ref('core_auth0__tenant_activity_daily') }}
GROUP BY 1
HAVING COUNT(*) > 1
