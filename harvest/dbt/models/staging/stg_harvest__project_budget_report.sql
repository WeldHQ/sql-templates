-- stg_harvest__project_budget_report
-- Thin wrapper over raw `project_budget_report`: Harvest's own Project Budget
-- report, re-pulled in full on every sync. One row per project.
--
-- `budget`, `budget_spent` and `budget_remaining` are in the unit given by
-- `budget_by`: hours for "project" and "task", money for "project_cost" and
-- "task_fees", per person for "person". For monthly budgets they cover the
-- current month only.

SELECT
    CAST(project_id AS STRING)          AS project_id,
    LOWER(CAST(budget_by AS STRING))    AS budget_by,
    COALESCE(budget_is_monthly, FALSE)  AS budget_is_monthly,
    CAST(budget AS FLOAT64)             AS budget,
    CAST(budget_spent AS FLOAT64)       AS budget_spent,
    CAST(budget_remaining AS FLOAT64)   AS budget_remaining
FROM {{ source('harvest', 'project_budget_report') }}
WHERE project_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(project_id AS STRING) ORDER BY _weld_synced DESC) = 1
