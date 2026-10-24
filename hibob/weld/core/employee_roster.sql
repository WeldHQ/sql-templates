-- core.hibob.employee_roster
-- One row per person: role, team, manager, employment terms, tenure and time off
-- taken in the last 12 months. HiBob's People directory plus a few derived columns.
-- Grain: employee (active and inactive).
--
-- Tenure is measured from the current start date to today, or to the termination
-- date for people who have left. Time off counts approved hours on days in the
-- last 365 days up to today.

WITH recent_time_off AS (
    SELECT
        d.employee_id,
        SUM(d.hours) AS approved_hours_off_last_12m
    FROM {{staging.hibob.time_off_day}} d
    JOIN {{staging.hibob.time_off_request}} r USING (request_id)
    WHERE r.status = 'approved'
      AND d.date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 364 DAY) AND CURRENT_DATE()
    GROUP BY 1
)

SELECT
    e.employee_id,
    e.display_name,
    e.email,
    e.job_title,
    e.department,
    e.site,
    e.manager_name,
    e.is_manager,
    e.employment_type,
    e.fte,
    e.status,
    e.lifecycle_status,
    e.start_date,
    e.original_start_date,
    IF(e.termination_date >= e.start_date, e.termination_date, NULL)           AS termination_date,
    e.termination_type,
    e.termination_reason,
    ROUND(DATE_DIFF(
        LEAST(CURRENT_DATE(), COALESCE(IF(e.termination_date >= e.start_date, e.termination_date, NULL), CURRENT_DATE())),
        e.start_date, DAY) / 365.25, 2)                                       AS tenure_years,
    ROUND(COALESCE(t.approved_hours_off_last_12m, 0), 2)                      AS approved_hours_off_last_12m
FROM {{staging.hibob.employee}} e
LEFT JOIN recent_time_off t USING (employee_id)
