-- stg_hibob__time_off_day
-- Thin wrapper over raw `timeoff_durations`. One row per request x day: how much
-- of each day a time off request covers. Hours and minutes arrive as two parts
-- and are combined into hours here.

SELECT
    CAST(request_id AS INT64)                       AS request_id,
    CAST(employee_id AS STRING)                     AS employee_id,
    SAFE_CAST(LEFT(CAST(date AS STRING), 10) AS DATE) AS date,
    COALESCE(CAST(day_duration_hours AS FLOAT64), 0)
      + COALESCE(CAST(day_duration_minutes AS FLOAT64), 0) / 60 AS hours,
    LOWER(CAST(day_duration_type AS STRING))        AS duration_type
FROM {{ source('hibob', 'timeoff_durations') }}
WHERE request_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(request_id AS INT64), CAST(date AS STRING)
    ORDER BY _weld_synced DESC
) = 1
