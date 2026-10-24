-- core_sona__absence_daily
-- Who was off, and why, per day: absence days by type and location, with sickness
-- and holiday split out. The basis for absence rate and sickness trend reporting.
--
-- Grain: one row per absence date x home org unit x absence type x day status.
-- Depends on: staging.sona.absence_days, staging.sona.absences,
--             staging.sona.absence_types, staging.sona.users
--
-- People are placed on their administrative (home) org unit, which is where Sona
-- holds their record, not on wherever they would have worked that day.
--
-- day_status is Sona's status for each absence day and is part of the grain rather
-- than filtered, because its values are not documented publicly. Look at the
-- distinct values in your data and filter in the analytics layer (for example to
-- approved days only) once you know them.

SELECT
    d.absence_date,
    u.home_org_unit_id                          AS org_unit_id,
    ANY_VALUE(o.org_unit_name)                  AS org_unit_name,
    a.absence_type_id,
    ANY_VALUE(t.absence_type_name)              AS absence_type_name,
    ANY_VALUE(t.is_sickness)                    AS is_sickness,
    ANY_VALUE(t.is_holiday)                     AS is_holiday,
    d.day_status,

    COUNT(*)                                    AS absence_days,
    COUNT(DISTINCT a.user_id)                   AS people_absent,
    COUNTIF(a.is_paid)                          AS paid_absence_days,
    COUNTIF(t.is_sickness AND a.sick_note_provided) AS sickness_days_with_sick_note
FROM {{ ref('stg_sona__absence_days') }} d
JOIN {{ ref('stg_sona__absences') }} a
  ON a.absence_id = d.absence_id
LEFT JOIN {{ ref('stg_sona__absence_types') }} t
  ON t.absence_type_id = a.absence_type_id
LEFT JOIN {{ ref('stg_sona__users') }} u
  ON u.user_id = a.user_id
LEFT JOIN {{ ref('stg_sona__org_units') }} o
  ON o.org_unit_id = u.home_org_unit_id
GROUP BY d.absence_date, u.home_org_unit_id, a.absence_type_id, d.day_status
