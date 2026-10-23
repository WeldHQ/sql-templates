-- On every row of headcount_monthly, end = start + hires - leavers.
-- Returns zero rows when it holds. A failure means a person landed in two
-- departments in the same month, which points at a fan-out in the work history join.

SELECT month_start, department, site, headcount_start, hires, leavers, headcount_end
FROM {{ ref('core_hibob__headcount_monthly') }}
WHERE headcount_end != headcount_start + hires - leavers
