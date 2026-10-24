-- staging.harvest.expense
-- Thin wrapper over raw `expense`. One row per expense, latest version.
-- `total_cost` is in the client's currency.

SELECT
    CAST(id AS STRING)                      AS expense_id,
    DATE(CAST(spent_date AS TIMESTAMP))     AS spent_date,
    CAST(user_id AS STRING)                 AS user_id,
    CAST(project_id AS STRING)              AS project_id,
    CAST(expense_category_name AS STRING)   AS expense_category_name,
    CAST(total_cost AS FLOAT64)             AS total_cost,
    COALESCE(billable, FALSE)               AS is_billable,
    COALESCE(is_billed, FALSE)              AS is_billed
FROM {{raw.harvest.expense}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
