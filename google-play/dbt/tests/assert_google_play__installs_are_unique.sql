-- One row per day, package and country after de-duplication.
-- Google rewrites the current month's file daily and it is read again on each sync;
-- without the de-duplication in staging, recent days would be counted once per
-- read.

SELECT
    date_day,
    package_name,
    country,
    COUNT(*) AS row_count
FROM {{ ref('core_google_play__installs_daily') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
