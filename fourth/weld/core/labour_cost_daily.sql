-- core.fourth.labour_cost_daily
-- Labour hours and cost per day and department, split by Fourth's payroll type,
-- pay part and status.
-- Grain: date x department x payroll type x pay part x status.
--
-- Keep the type, pay part and status columns in view: they are Fourth's own
-- labels and vary by account. Look at the distinct values before summing across
-- them, for example to keep only approved lines or to leave out holiday pay.

SELECT
    p.date,
    dl.location_id,
    dl.location_name,
    p.department_id,
    ANY_VALUE(p.department_name)             AS department_name,
    p.payroll_type,
    p.pay_part,
    p.status,
    COUNT(DISTINCT p.employee_id)            AS employees,
    SUM(p.hours)                            AS hours,
    SUM(p.pay_value)                        AS labour_cost
FROM {{staging.fourth.payroll}} p
LEFT JOIN {{core.fourth.department_location}} dl USING (department_id)
GROUP BY p.date, dl.location_id, dl.location_name, p.department_id, p.payroll_type, p.pay_part, p.status
