-- core.sona.shift_coverage_daily
-- Rota coverage per location and shift type: how many shifts were planned, how many
-- were filled by your own staff, how many by an agency, and how many are still open.
-- Covers upcoming shifts as well as past ones, so it doubles as a look-ahead of
-- open shifts to fill.
--
-- Grain: one row per local shift date x org unit x shift type.
-- Depends on: staging.sona.shifts, staging.sona.org_units
--
-- Shifts are dated in the org unit's own time zone (org_units.timezone, falling
-- back to UTC), so a night shift starting at 22:00 local is on the day it starts.
--
-- FILLED, AGENCY, OPEN. A shift with an agency on it counts as agency. Otherwise
-- it is filled when it is linked to an employment period or a user, and open when
-- it is linked to neither. Sona's own wording for these states may differ;
-- check one week against the rota view and adjust the CASE if it does.
--
-- Draft copies of shifts (draft_of_shift_id set) and travel gaps between visits are
-- not shifts and are left out of the counts; travel time is reported separately.
-- Hours are start to finish and include breaks.

WITH shifts AS (
    SELECT
        s.*,
        DATE(s.starts_at, COALESCE(o.timezone, 'UTC'))          AS shift_date,
        TIMESTAMP_DIFF(s.finishes_at, s.starts_at, MINUTE) / 60.0 AS shift_hours,
        CASE
            WHEN s.agency_id IS NOT NULL                                        THEN 'agency'
            WHEN s.employment_period_id IS NOT NULL
              OR s.user_working_shift_id IS NOT NULL                            THEN 'filled'
            ELSE 'open'
        END                                                     AS fill_status
    FROM {{staging.sona.shifts}} s
    LEFT JOIN {{staging.sona.org_units}} o
      ON o.org_unit_id = s.org_unit_id
    WHERE s.draft_of_shift_id IS NULL
)

SELECT
    s.shift_date,
    s.org_unit_id,
    ANY_VALUE(o.org_unit_name)                                  AS org_unit_name,
    s.shift_type_id,
    ANY_VALUE(s.shift_type_name)                                AS shift_type_name,

    COUNTIF(NOT s.is_travel_gap)                                AS shifts,
    COUNTIF(NOT s.is_travel_gap AND s.fill_status = 'filled')   AS filled_shifts,
    COUNTIF(NOT s.is_travel_gap AND s.fill_status = 'agency')   AS agency_shifts,
    COUNTIF(NOT s.is_travel_gap AND s.fill_status = 'open')     AS open_shifts,

    SUM(IF(NOT s.is_travel_gap, s.shift_hours, 0))              AS planned_hours,
    SUM(IF(NOT s.is_travel_gap AND s.fill_status = 'filled', s.shift_hours, 0)) AS filled_hours,
    SUM(IF(NOT s.is_travel_gap AND s.fill_status = 'agency', s.shift_hours, 0)) AS agency_hours,
    SUM(IF(NOT s.is_travel_gap AND s.fill_status = 'open', s.shift_hours, 0))   AS open_hours,
    SUM(IF(s.is_travel_gap, s.shift_hours, 0))                  AS travel_gap_hours,

    -- Share of planned hours covered by anyone, and by an agency. Computed from hour
    -- sums in this row, so roll up by summing the hour columns and dividing again.
    ROUND(SAFE_DIVIDE(SUM(IF(NOT s.is_travel_gap AND s.fill_status != 'open', s.shift_hours, 0)),
                      SUM(IF(NOT s.is_travel_gap, s.shift_hours, 0))), 4) AS fill_rate,
    ROUND(SAFE_DIVIDE(SUM(IF(NOT s.is_travel_gap AND s.fill_status = 'agency', s.shift_hours, 0)),
                      SUM(IF(NOT s.is_travel_gap, s.shift_hours, 0))), 4) AS agency_share
FROM shifts s
LEFT JOIN {{staging.sona.org_units}} o
  ON o.org_unit_id = s.org_unit_id
GROUP BY s.shift_date, s.org_unit_id, s.shift_type_id
