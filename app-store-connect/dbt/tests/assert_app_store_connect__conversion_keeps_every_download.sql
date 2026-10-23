-- product_page_conversion keeps every download from downloads_and_deletions.
-- The two are full-outer-joined on day, app, territory, source type and device. If
-- a join column is NULL on one side, rows stop matching and either drop or split;
-- this checks the download totals survive the join, per day and app.

WITH conversion AS (
    SELECT date_day, app_apple_id, SUM(first_time_downloads) AS first_time_downloads
    FROM {{ ref('core_app_store_connect__product_page_conversion') }}
    GROUP BY 1, 2
),

downloads AS (
    SELECT date_day, app_apple_id, SUM(first_time_downloads) AS first_time_downloads
    FROM {{ ref('core_app_store_connect__downloads_and_deletions') }}
    GROUP BY 1, 2
)

SELECT d.*, c.first_time_downloads AS conversion_first_time_downloads
FROM downloads d
LEFT JOIN conversion c
  ON  c.date_day = d.date_day
  AND c.app_apple_id = d.app_apple_id
WHERE COALESCE(c.first_time_downloads, -1) != d.first_time_downloads
