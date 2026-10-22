-- stg_hibob__work_history
-- Thin wrapper over raw `employee_work_history`. One row per work history entry:
-- a change of department, site, title or manager with the date it took effect.
--
-- Department is stored as the id of an entry in HiBob's department list; it is
-- resolved to a name through staging.hibob.entity_name in core. Site comes as a
-- name already.

SELECT
    CAST(id AS STRING)                              AS work_history_id,
    CAST(employee_id AS STRING)                     AS employee_id,
    DATE(CAST(effective_date AS TIMESTAMP))         AS effective_date,
    DATE(CAST(end_effective_date AS TIMESTAMP))     AS end_effective_date,
    CAST(department AS STRING)                      AS department_ref,
    CAST(site AS STRING)                            AS site,
    CAST(title AS STRING)                           AS title_ref,
    CAST(reports_to_display_name AS STRING)         AS manager_name,
    COALESCE(is_current, FALSE)                     AS is_current
FROM {{ source('hibob', 'employee_work_history') }}
WHERE employee_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY _weld_synced DESC) = 1
