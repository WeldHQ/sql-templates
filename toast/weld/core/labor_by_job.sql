-- core.toast.labor_by_job
-- Toast's Labor Summary by job: hours and wage cost per business day.
-- Grain: business date x restaurant x job.
--
-- Cost is hours x the hourly wage on each time entry:
--   regular_cost  = regular_hours x hourly_wage
--   overtime_cost = overtime_hours x hourly_wage x 1.5
-- The 1.5 overtime multiplier is the US default. Toast lets you change it per
-- location; change it here if yours differs. Salaried staff and entries without a
-- wage add hours but no cost: entries_without_wage counts them.
-- Jobs marked "exclude from reporting" in Toast are kept and flagged.

SELECT
    t.business_date,
    t.restaurant_id,
    t.job_id,
    ANY_VALUE(j.job_title)                                         AS job_title,
    ANY_VALUE(j.is_tipped)                                         AS is_tipped,
    ANY_VALUE(j.exclude_from_reporting)                            AS exclude_from_reporting,
    COUNT(DISTINCT t.employee_id)                                  AS employees,
    COUNT(*)                                                       AS time_entries,
    ROUND(SUM(t.regular_hours), 2)                                 AS regular_hours,
    ROUND(SUM(t.overtime_hours), 2)                                AS overtime_hours,
    ROUND(SUM(t.regular_hours + t.overtime_hours), 2)              AS total_hours,
    ROUND(SUM(t.regular_hours * COALESCE(t.hourly_wage, 0)), 2)    AS regular_cost,
    ROUND(SUM(t.overtime_hours * COALESCE(t.hourly_wage, 0) * 1.5), 2) AS overtime_cost,
    ROUND(SUM(t.regular_hours * COALESCE(t.hourly_wage, 0)
            + t.overtime_hours * COALESCE(t.hourly_wage, 0) * 1.5), 2) AS labor_cost,
    ROUND(SUM(t.declared_cash_tips + t.non_cash_tips), 2)          AS tips,
    COUNTIF(t.hourly_wage IS NULL OR t.hourly_wage = 0)            AS entries_without_wage,
    COUNTIF(t.was_auto_clocked_out)                                AS auto_clocked_out_entries
FROM {{staging.toast.time_entry}} t
LEFT JOIN {{staging.toast.job}} j
       ON j.job_id = t.job_id AND j.restaurant_id = t.restaurant_id
WHERE t.business_date IS NOT NULL
GROUP BY t.business_date, t.restaurant_id, t.job_id
