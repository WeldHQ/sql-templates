-- stg_facebook_pages__page_daily_insights
-- Thin wrapper over raw `page_daily_insights`, the Page Insights metrics with
-- period `day`. Casts, renames, turns Facebook's end_time into the day it
-- describes, keeps the latest row per key. No other logic.
--
-- Grain: page x day x metric x breakdown (long format: one row per value).
-- Metrics that Facebook returns as an object, such as reactions by type or new
-- likes split paid and unpaid, arrive as one row per key; the key is in
-- `breakdown`. Plain metrics have breakdown NULL.
--
-- DAYS. Facebook stamps a daily value with the end of the day, midnight Pacific
-- Time of the next day (07:00 or 08:00 UTC). date_day is that day minus one, in
-- Pacific Time, which is the day the Page Insights UI shows the value on.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(page_id AS STRING)                                                 AS page_id,
        DATE_SUB(DATE(CAST(end_time AS TIMESTAMP), 'America/Los_Angeles'), INTERVAL 1 DAY) AS date_day,
        CAST(name AS STRING)                                                    AS metric,
        NULLIF(NULLIF(CAST(type AS STRING), 'none'), 'unknown')                 AS breakdown,
        CAST(COALESCE(value, 0) AS FLOAT64)                                     AS value,
        ROW_NUMBER() OVER (
            PARTITION BY page_id, name, type, end_time ORDER BY _weld_synced DESC
        )                                                                       AS row_rank
    FROM {{ source('facebook_pages', 'page_daily_insights') }}
    WHERE period = 'day'
      AND end_time IS NOT NULL
)
WHERE row_rank = 1
