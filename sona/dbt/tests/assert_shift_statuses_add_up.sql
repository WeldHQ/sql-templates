-- Filled, agency and open shifts add up to all shifts, and their hours to planned
-- hours. Every shift gets exactly one fill status, so a gap means the CASE in
-- shift_coverage_daily lets a shift through without one.

SELECT *
FROM {{ ref('core_sona__shift_coverage_daily') }}
WHERE filled_shifts + agency_shifts + open_shifts != shifts
   OR ABS(filled_hours + agency_hours + open_hours - planned_hours) > 0.01
