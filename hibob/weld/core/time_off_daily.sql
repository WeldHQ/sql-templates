-- core.hibob.time_off_daily
-- Time off taken or booked, per day, person and policy.
-- Grain: date x employee x policy type x request status.
--
-- Built from the per-day breakdown HiBob attaches to each request, so a
-- two-week holiday shows on each working day it covers with the hours it takes
-- that day. Status is approved or pending; filter to approved for time actually
-- granted. Future-dated requests are included, so this doubles as a "who's out
-- next month" view.
--
-- Department is the person's CURRENT department.

SELECT
    d.date,
    d.employee_id,
    COALESCE(e.display_name, r.employee_display_name)  AS employee_name,
    e.department,
    e.site,
    r.policy_type,
    r.policy_type_name,
    r.status,
    COUNT(DISTINCT d.request_id)                        AS requests,
    ROUND(SUM(d.hours), 2)                              AS hours_off
FROM {{staging.hibob.time_off_day}} d
JOIN {{staging.hibob.time_off_request}} r USING (request_id)
LEFT JOIN {{staging.hibob.employee}} e ON e.employee_id = d.employee_id
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
