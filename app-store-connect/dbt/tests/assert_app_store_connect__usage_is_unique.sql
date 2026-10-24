-- One row per day, app, app version and device in usage_and_stability.
-- A duplicate means the sessions or crashes side is no longer unique at that grain,
-- and crashes per session would be computed against the wrong denominator.

SELECT
    date_day,
    app_apple_id,
    app_version,
    device,
    COUNT(*) AS row_count
FROM {{ ref('core_app_store_connect__usage_and_stability') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
