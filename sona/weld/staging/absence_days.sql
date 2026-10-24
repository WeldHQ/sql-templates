-- staging.sona.absence_days
-- Thin wrapper over raw `absence_days`: the calendar days each absence covers.
-- Casts, renames, keeps the latest status of each day.
--
-- Grain: one row per absence x date.

SELECT
    CAST(absence_id AS STRING)  AS absence_id,
    CAST(date AS DATE)          AS absence_date,
    CAST(status AS STRING)      AS day_status
FROM {{raw.sona.absence_days}}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (PARTITION BY absence_id, date ORDER BY _weld_synced DESC) = 1
