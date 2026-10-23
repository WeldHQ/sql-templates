-- absence_daily counts every absence day that belongs to a known absence once.
-- The joins to types, users and org units are LEFT JOINs on unique keys, so the
-- total must match the staging rows that join to an absence.

WITH report AS (
    SELECT SUM(absence_days) AS absence_days
    FROM {{ ref('core_sona__absence_daily') }}
),

source AS (
    SELECT COUNT(*) AS absence_days
    FROM {{ ref('stg_sona__absence_days') }} d
    JOIN {{ ref('stg_sona__absences') }} a USING (absence_id)
)

SELECT *
FROM report, source
WHERE report.absence_days != source.absence_days
