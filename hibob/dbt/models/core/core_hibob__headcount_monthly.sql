-- core_hibob__headcount_monthly
-- Headcount, hires, leavers and turnover per month, department and site.
-- HiBob's headcount and turnover analytics, as a table.
-- Grain: month x department x site.
--
-- Employment spans come from each person's start date and termination date. A
-- person counts in the headcount on a day from their start date up to and
-- including their termination date (HiBob's termination date is the last day
-- worked). Department and site are as of the month end, or as of the
-- termination date for leavers, read from work history; people with no work
-- history fall back to their current department and site.
--
-- The identity headcount_end = headcount_start + hires - leavers holds on every
-- row, because each person-month sits in exactly one department. Moves between
-- departments therefore show up as a change in headcount without a hire or
-- leaver; there are no transfer columns.
--
-- The current month runs to CURRENT_DATE(), not to the month end.
--
-- Rehires: HiBob keeps one employee record, and start_date is the start of the
-- current employment. A rehired person's earlier employment is not counted, and a
-- termination date before the current start date is ignored.

WITH employees AS (
    SELECT
        employee_id,
        start_date,
        IF(termination_date >= start_date, termination_date, NULL)  AS termination_date,
        LOWER(termination_type)                                     AS termination_type,
        department                                                  AS current_department,
        site                                                        AS current_site
    FROM {{ ref('stg_hibob__employee') }}
    WHERE start_date IS NOT NULL
),

months AS (
    SELECT
        month_start,
        DATE_SUB(month_start, INTERVAL 1 DAY)                AS previous_month_end,
        LEAST(LAST_DAY(month_start, MONTH), CURRENT_DATE())  AS month_end
    FROM UNNEST(GENERATE_DATE_ARRAY(
        DATE_TRUNC((SELECT MIN(start_date) FROM employees), MONTH),
        DATE_TRUNC(CURRENT_DATE(), MONTH),
        INTERVAL 1 MONTH
    )) AS month_start
),

employee_months AS (
    SELECT
        m.month_start,
        e.employee_id,
        e.current_department,
        e.current_site,
        e.termination_type,
        LEAST(m.month_end, COALESCE(e.termination_date, m.month_end))          AS as_of_date,
        e.start_date <= m.previous_month_end
            AND (e.termination_date IS NULL OR e.termination_date > m.previous_month_end) AS in_headcount_start,
        e.start_date <= m.month_end
            AND (e.termination_date IS NULL OR e.termination_date > m.month_end)          AS in_headcount_end,
        e.start_date BETWEEN m.month_start AND m.month_end                                AS is_hire,
        COALESCE(e.termination_date BETWEEN m.month_start AND m.month_end, FALSE)         AS is_leaver
    FROM months m
    JOIN employees e
      ON e.start_date <= m.month_end
     AND (e.termination_date IS NULL OR e.termination_date >= m.month_start)
),

departments AS (
    SELECT item_id, COALESCE(item_name, item_value) AS department_name
    FROM {{ ref('stg_hibob__entity_name') }}
    WHERE list_name = 'department'
),

with_org AS (
    SELECT
        em.*,
        COALESCE(d.department_name, wh.department_ref, em.current_department) AS department,
        COALESCE(wh.site, em.current_site)                                    AS site
    FROM employee_months em
    LEFT JOIN {{ ref('stg_hibob__work_history') }} wh
      ON wh.employee_id = em.employee_id
     AND wh.effective_date <= em.as_of_date
    LEFT JOIN departments d ON d.item_id = wh.department_ref
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY em.employee_id, em.month_start
        ORDER BY wh.effective_date DESC, wh.work_history_id DESC
    ) = 1
)

SELECT
    month_start,
    department,
    site,
    COUNTIF(in_headcount_start)                                         AS headcount_start,
    COUNTIF(is_hire)                                                    AS hires,
    COUNTIF(is_leaver)                                                  AS leavers,
    COUNTIF(is_leaver AND termination_type LIKE '%voluntary%'
            AND termination_type NOT LIKE '%involuntary%')              AS voluntary_leavers,
    COUNTIF(is_leaver AND termination_type LIKE '%involuntary%')        AS involuntary_leavers,
    COUNTIF(in_headcount_end)                                           AS headcount_end,
    SAFE_DIVIDE(COUNTIF(is_leaver),
                (COUNTIF(in_headcount_start) + COUNTIF(in_headcount_end)) / 2) AS turnover_rate
FROM with_org
GROUP BY 1, 2, 3
