-- staging.hibob.employee
-- Thin wrapper over raw `employee`. One row per person in HiBob, active and
-- inactive, as of the last sync (the stream is a full refresh).
--
-- HiBob returns every field up to three ways: nested (`work_department`),
-- slash-keyed (`work_department_value`) and human readable
-- (`human_readable_work_department`). List fields such as department hold an id in
-- the first two forms and the display name in the third, so names prefer the
-- human-readable form and fall back to the others.
--
-- Fields the HiBob service user may not read are silently left out by HiBob, so a
-- column that is NULL for everyone usually means a missing permission.

SELECT
    CAST(id AS STRING)                                                         AS employee_id,
    COALESCE(display_name, full_name)                                          AS display_name,
    LOWER(CAST(email AS STRING))                                               AS email,
    COALESCE(human_readable_work_title, work_title, work_title_value)          AS job_title,
    COALESCE(human_readable_work_department, work_department, work_department_value) AS department,
    COALESCE(human_readable_work_site, work_site, work_site_value)             AS site,
    CAST(work_reports_to_display_name AS STRING)                               AS manager_name,
    COALESCE(work_is_manager, FALSE)                                           AS is_manager,
    COALESCE(human_readable_payroll_employment_type, payroll_employment_type)  AS employment_type,
    COALESCE(payroll_employment_fte, payroll_employment_fte_value)             AS fte,
    LOWER(COALESCE(human_readable_internal_status, internal_status, internal_status_value)) AS status,
    LOWER(COALESCE(human_readable_internal_lifecycle_status, internal_lifecycle_status,
                   internal_lifecycle_status_value))                           AS lifecycle_status,
    DATE(CAST(COALESCE(work_start_date, work_start_date_value) AS TIMESTAMP))  AS start_date,
    DATE(CAST(COALESCE(work_original_start_date, employee_first_day_of_work) AS TIMESTAMP)) AS original_start_date,
    DATE(CAST(COALESCE(internal_termination_date, internal_termination_date_value) AS TIMESTAMP)) AS termination_date,
    COALESCE(human_readable_internal_termination_type, internal_termination_type)     AS termination_type,
    COALESCE(human_readable_internal_termination_reason, internal_termination_reason) AS termination_reason
FROM {{raw.hibob.employee}}
WHERE id IS NOT NULL
