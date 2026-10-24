-- staging.fourth.labour_daily_summary
-- Thin wrapper over raw `labour_daily_summary`: Fourth's daily staffing accuracy
-- per location, hours worked when correctly staffed, understaffed or overstaffed
-- against the staffing requirement. One row per location x day.

SELECT
    CAST(location_id AS STRING)             AS location_id,
    CAST(location_name AS STRING)           AS location_name,
    DATE(date)                              AS date,
    CAST(correctly_staffed_hours AS FLOAT64) AS correctly_staffed_hours,
    CAST(understaffed_hours AS FLOAT64)     AS understaffed_hours,
    CAST(overstaffed_hours AS FLOAT64)      AS overstaffed_hours,
    CAST(passive_hours AS FLOAT64)          AS passive_hours
FROM {{raw.fourth.labour_daily_summary}}
WHERE location_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(location_id AS STRING), DATE(date)
    ORDER BY _weld_synced DESC
) = 1
